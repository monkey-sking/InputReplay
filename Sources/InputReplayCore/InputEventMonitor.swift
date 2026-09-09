import Foundation
import CoreGraphics

public final class InputEventMonitor: @unchecked Sendable {
    public typealias EventHandler = @Sendable (CapturedKeyEvent) -> Void
    public typealias PhysicalEventFilter = @Sendable (CapturedKeyEvent) -> Bool

    private struct RawKeyEvent: Sendable {
        let timestamp: TimeInterval
        let keyCode: CGKeyCode
        let flagsRawValue: UInt64
        let characters: String?
        let fallbackPID: pid_t
        let inputSourceID: String
        let isSynthetic: Bool
        let isRepeat: Bool
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let inputSources: InputSourceController
    private let physicalEventFilter: PhysicalEventFilter
    private let handler: EventHandler
    private let processingQueue = DispatchQueue(
        label: "com.inputreplay.event-processing",
        qos: .userInteractive
    )
    private let stateLock = NSLock()
    private var acceptingEvents = false

    public init(
        inputSources: InputSourceController = InputSourceController(),
        physicalEventFilter: @escaping PhysicalEventFilter = { _ in true },
        handler: @escaping EventHandler
    ) {
        self.inputSources = inputSources
        self.physicalEventFilter = physicalEventFilter
        self.handler = handler
    }

    deinit {
        stop()
    }

    @discardableResult
    public func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let monitor = Unmanaged<InputEventMonitor>
                .fromOpaque(userInfo)
                .takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                monitor.reenableEventTap()
                return Unmanaged.passUnretained(event)
            }

            guard type == .keyDown else {
                return Unmanaged.passUnretained(event)
            }

            // Keep the event-tap callback extremely small. Cross-process AX
            // inspection is deferred to a serial queue so slow host apps cannot
            // cause macOS to disable the event tap while the user is typing.
            monitor.enqueue(event)
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        setAcceptingEvents(true)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    public func stop() {
        setAcceptingEvents(false)
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
    }

    private func enqueue(_ event: CGEvent) {
        guard isAcceptingEvents() else { return }

        let raw = RawKeyEvent(
            timestamp: ProcessInfo.processInfo.systemUptime,
            keyCode: CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode)),
            flagsRawValue: event.flags.rawValue,
            characters: unicodeProjection(of: event),
            fallbackPID: pid_t(event.getIntegerValueField(.eventSourceUnixProcessID)),
            inputSourceID: inputSources.current()?.id ?? "unknown",
            isSynthetic: event.getIntegerValueField(.eventSourceUserData) == SyntheticEventMarker.value,
            isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        )

        processingQueue.async { [weak self] in
            self?.process(raw)
        }
    }

    private func process(_ raw: RawKeyEvent) {
        guard isAcceptingEvents() else { return }

        if raw.isSynthetic {
            // Deliver the marker so diagnostic consumers can observe it, while
            // InputReplayRuntime itself filters synthetic events before storage.
            handler(
                CapturedKeyEvent(
                    timestamp: raw.timestamp,
                    keyCode: raw.keyCode,
                    flagsRawValue: raw.flagsRawValue,
                    characters: raw.characters,
                    sourcePID: raw.fallbackPID,
                    focusIdentity: nil,
                    inputSourceID: raw.inputSourceID,
                    isSynthetic: true,
                    isRepeat: raw.isRepeat
                )
            )
            return
        }

        // Physical capture is fail-closed. Cross-process Accessibility work is
        // done here, outside the EventTap callback.
        guard !InputPrivacyGuard.isSecureEventInputEnabled else { return }
        guard let focusedContext = InputPrivacyGuard.focusedContext(), !focusedContext.isSecure else {
            return
        }
        guard isAcceptingEvents() else { return }

        let captured = CapturedKeyEvent(
            timestamp: raw.timestamp,
            keyCode: raw.keyCode,
            flagsRawValue: raw.flagsRawValue,
            characters: raw.characters,
            sourcePID: focusedContext.processID,
            focusIdentity: focusedContext.focusIdentity,
            inputSourceID: raw.inputSourceID,
            isSynthetic: false,
            isRepeat: raw.isRepeat
        )

        // Product shortcuts must not become user content or invalidate the
        // recovery window they are trying to activate.
        guard physicalEventFilter(captured) else { return }
        handler(captured)
    }

    private func reenableEventTap() {
        guard let tap = eventTap, isAcceptingEvents() else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func setAcceptingEvents(_ value: Bool) {
        stateLock.lock()
        acceptingEvents = value
        stateLock.unlock()
    }

    private func isAcceptingEvents() -> Bool {
        stateLock.lock()
        let value = acceptingEvents
        stateLock.unlock()
        return value
    }

    private func unicodeProjection(of event: CGEvent) -> String? {
        var actualLength = 0
        var buffer = [UniChar](repeating: 0, count: 16)
        buffer.withUnsafeMutableBufferPointer { pointer in
            event.keyboardGetUnicodeString(
                maxStringLength: pointer.count,
                actualStringLength: &actualLength,
                unicodeString: pointer.baseAddress
            )
        }

        guard actualLength > 0 else { return nil }
        return String(utf16CodeUnits: buffer, count: actualLength)
    }
}

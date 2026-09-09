import Foundation
import CoreGraphics

public final class InputEventMonitor: @unchecked Sendable {
    public typealias EventHandler = @Sendable (CapturedKeyEvent) -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let inputSources: InputSourceController
    private let handler: EventHandler

    public init(
        inputSources: InputSourceController = InputSourceController(),
        handler: @escaping EventHandler
    ) {
        self.inputSources = inputSources
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
            guard type == .keyDown, let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let monitor = Unmanaged<InputEventMonitor>
                .fromOpaque(userInfo)
                .takeUnretainedValue()

            monitor.consume(event)
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
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
    }

    private func consume(_ event: CGEvent) {
        let marker = event.getIntegerValueField(.eventSourceUserData)
        let isSynthetic = marker == SyntheticEventMarker.value
        let sourcePID = pid_t(event.getIntegerValueField(.eventSourceUnixProcessID))
        let sourceID = inputSources.current()?.id ?? "unknown"

        let captured = CapturedKeyEvent(
            timestamp: ProcessInfo.processInfo.systemUptime,
            keyCode: CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode)),
            flagsRawValue: event.flags.rawValue,
            characters: nil,
            sourcePID: sourcePID,
            focusIdentity: nil,
            inputSourceID: sourceID,
            isSynthetic: isSynthetic
        )

        handler(captured)
    }
}

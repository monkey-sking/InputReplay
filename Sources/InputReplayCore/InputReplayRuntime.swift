import Foundation

/// Non-destructive runtime foundation.
///
/// This layer captures recent physical key metadata and turns actual TIS input
/// source changes into short-lived suggestion signals. It does not perform
/// recovery by itself and therefore cannot mutate user text.
public final class InputReplayRuntime: @unchecked Sendable {
    public typealias SwitchSuggestionHandler = @Sendable (InputSourceSwitchSignal) -> Void
    public typealias PhysicalEventFilter = InputEventMonitor.PhysicalEventFilter

    private let inputSources: InputSourceController
    private let ringBuffer: KeystrokeRingBuffer
    private let contextTracker: InputContextTracker
    private let physicalEventFilter: PhysicalEventFilter
    private let suggestionHandler: SwitchSuggestionHandler

    private var eventMonitor: InputEventMonitor?
    private var running = false

    public init(
        inputSources: InputSourceController = InputSourceController(),
        ringBuffer: KeystrokeRingBuffer = KeystrokeRingBuffer(),
        contextTracker: InputContextTracker = InputContextTracker(),
        physicalEventFilter: @escaping PhysicalEventFilter = { _ in true },
        suggestionHandler: @escaping SwitchSuggestionHandler
    ) {
        self.inputSources = inputSources
        self.ringBuffer = ringBuffer
        self.contextTracker = contextTracker
        self.physicalEventFilter = physicalEventFilter
        self.suggestionHandler = suggestionHandler
    }

    @discardableResult
    public func start() async -> Bool {
        guard !running else { return true }

        if let current = inputSources.current() {
            let focus = InputPrivacyGuard.focusedContext()
            _ = await contextTracker.inputSourceDidChange(
                to: current.id,
                sourcePID: focus?.processID ?? 0,
                focusIdentity: focus?.focusIdentity
            )
        }

        inputSources.startObserving { [weak self] source in
            guard let self, let source else { return }
            Task {
                let focus = InputPrivacyGuard.focusedContext()
                if InputPrivacyGuard.isSecureEventInputEnabled || focus?.isSecure == true {
                    await self.clearSensitiveRecentState()
                    return
                }

                guard let signal = await self.contextTracker.inputSourceDidChange(
                    to: source.id,
                    sourcePID: focus?.processID ?? 0,
                    focusIdentity: focus?.focusIdentity
                ) else {
                    return
                }
                self.suggestionHandler(signal)
            }
        }

        let monitor = InputEventMonitor(
            inputSources: inputSources,
            physicalEventFilter: physicalEventFilter
        ) { [weak self] event in
            guard let self, !event.isSynthetic else { return }
            Task {
                await self.ringBuffer.append(event)
                await self.contextTracker.ingest(event)
            }
        }

        guard monitor.start() else {
            inputSources.stopObserving()
            return false
        }

        eventMonitor = monitor
        running = true
        return true
    }

    public func stop() async {
        guard running else { return }
        eventMonitor?.stop()
        eventMonitor = nil
        inputSources.stopObserving()
        await clearSensitiveRecentState()
        running = false
    }

    /// Call on strong lifecycle/focus boundaries such as sleep/wake recovery,
    /// permission loss, listener reinitialization, or an explicit privacy reset.
    public func clearSensitiveRecentState() async {
        await ringBuffer.clear()
        await contextTracker.invalidateForLifecycleBoundary()
    }

    public func recentPhysicalEvents() async -> [CapturedKeyEvent] {
        await ringBuffer.snapshot()
    }

    public func pendingSwitchSuggestion() async -> InputSourceSwitchSignal? {
        await contextTracker.pendingSuggestion()
    }
}

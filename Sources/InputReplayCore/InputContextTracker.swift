import Foundation

public struct InputSourceSwitchSignal: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let occurredAt: TimeInterval
    public let previousInputSourceID: String
    public let newInputSourceID: String
    public let previousBurst: TypingBurst?
    public let expiresAt: TimeInterval

    public init(
        id: UUID = UUID(),
        occurredAt: TimeInterval,
        previousInputSourceID: String,
        newInputSourceID: String,
        previousBurst: TypingBurst?,
        expiresAt: TimeInterval
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.previousInputSourceID = previousInputSourceID
        self.newInputSourceID = newInputSourceID
        self.previousBurst = previousBurst
        self.expiresAt = expiresAt
    }

    public func isValid(at time: TimeInterval) -> Bool {
        time <= expiresAt
    }
}

/// Tracks the semantic timeline around input-source changes.
///
/// An input-source change is a strong *suggestion signal*, never permission to
/// rewrite text. The previous burst is frozen for a short window; any new
/// physical typing after the switch invalidates that signal so stale text is
/// never recovered after the user has continued writing.
public actor InputContextTracker {
    public struct Configuration: Sendable, Equatable {
        public var burstIdleGap: TimeInterval
        public var switchDebounce: TimeInterval
        public var suggestionTTL: TimeInterval

        public init(
            burstIdleGap: TimeInterval = 1.25,
            switchDebounce: TimeInterval = 0.12,
            suggestionTTL: TimeInterval = 3.0
        ) {
            self.burstIdleGap = burstIdleGap
            self.switchDebounce = switchDebounce
            self.suggestionTTL = suggestionTTL
        }
    }

    private let configuration: Configuration
    private var currentEpoch: InputSourceEpoch?
    private var burstEvents: [CapturedKeyEvent] = []
    private var lastPhysicalEventAt: TimeInterval?
    private var lastAcceptedSwitchAt: TimeInterval?
    private var pendingSwitchSignal: InputSourceSwitchSignal?

    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
    }

    public func ingest(_ event: CapturedKeyEvent) {
        guard !event.isSynthetic else { return }

        // New user typing after a source switch means the user has moved on;
        // never keep a stale recovery offer alive while new content is entered.
        if pendingSwitchSignal != nil {
            pendingSwitchSignal = nil
        }

        if currentEpoch?.inputSourceID != event.inputSourceID {
            startEpoch(
                inputSourceID: event.inputSourceID,
                at: event.timestamp,
                sourcePID: event.sourcePID,
                focusIdentity: event.focusIdentity
            )
        }

        if let lastPhysicalEventAt,
           event.timestamp - lastPhysicalEventAt > configuration.burstIdleGap {
            burstEvents.removeAll(keepingCapacity: true)
        }

        burstEvents.append(event)
        lastPhysicalEventAt = event.timestamp
    }

    /// Call only for an actually observed TIS source change, not for a guessed
    /// shortcut gesture. Returns a short-lived signal containing the previous
    /// typing burst when available.
    @discardableResult
    public func inputSourceDidChange(
        to newInputSourceID: String,
        at time: TimeInterval = ProcessInfo.processInfo.systemUptime,
        sourcePID: pid_t = 0,
        focusIdentity: String? = nil
    ) -> InputSourceSwitchSignal? {
        if let lastAcceptedSwitchAt,
           time - lastAcceptedSwitchAt < configuration.switchDebounce {
            return nil
        }

        let previousSourceID = currentEpoch?.inputSourceID
        guard let previousSourceID, previousSourceID != newInputSourceID else {
            if currentEpoch == nil {
                startEpoch(
                    inputSourceID: newInputSourceID,
                    at: time,
                    sourcePID: sourcePID,
                    focusIdentity: focusIdentity
                )
            }
            return nil
        }

        let previousBurst: TypingBurst?
        if let epoch = currentEpoch, !burstEvents.isEmpty {
            previousBurst = TypingBurst(epochID: epoch.id, events: burstEvents)
        } else {
            previousBurst = nil
        }

        let signal = InputSourceSwitchSignal(
            occurredAt: time,
            previousInputSourceID: previousSourceID,
            newInputSourceID: newInputSourceID,
            previousBurst: previousBurst,
            expiresAt: time + configuration.suggestionTTL
        )

        pendingSwitchSignal = signal
        lastAcceptedSwitchAt = time
        startEpoch(
            inputSourceID: newInputSourceID,
            at: time,
            sourcePID: sourcePID,
            focusIdentity: focusIdentity
        )
        return signal
    }

    public func pendingSuggestion(at time: TimeInterval = ProcessInfo.processInfo.systemUptime) -> InputSourceSwitchSignal? {
        guard let signal = pendingSwitchSignal else { return nil }
        guard signal.isValid(at: time) else {
            pendingSwitchSignal = nil
            return nil
        }
        return signal
    }

    public func invalidateForFocusChange(
        inputSourceID: String,
        at time: TimeInterval = ProcessInfo.processInfo.systemUptime,
        sourcePID: pid_t = 0,
        focusIdentity: String? = nil
    ) {
        pendingSwitchSignal = nil
        burstEvents.removeAll(keepingCapacity: true)
        lastPhysicalEventAt = nil
        startEpoch(
            inputSourceID: inputSourceID,
            at: time,
            sourcePID: sourcePID,
            focusIdentity: focusIdentity
        )
    }

    public func invalidateForLifecycleBoundary() {
        pendingSwitchSignal = nil
        burstEvents.removeAll(keepingCapacity: true)
        lastPhysicalEventAt = nil
        currentEpoch = nil
        lastAcceptedSwitchAt = nil
    }

    public func epoch() -> InputSourceEpoch? {
        currentEpoch
    }

    private func startEpoch(
        inputSourceID: String,
        at time: TimeInterval,
        sourcePID: pid_t,
        focusIdentity: String?
    ) {
        currentEpoch = InputSourceEpoch(
            startedAt: time,
            inputSourceID: inputSourceID,
            sourcePID: sourcePID,
            focusIdentity: focusIdentity
        )
        burstEvents.removeAll(keepingCapacity: true)
        lastPhysicalEventAt = nil
    }
}

import Foundation

public actor KeystrokeRingBuffer {
    public struct Limits: Sendable, Equatable {
        public var maxAge: TimeInterval
        public var maxCount: Int

        public init(maxAge: TimeInterval = 15, maxCount: Int = 128) {
            self.maxAge = maxAge
            self.maxCount = maxCount
        }
    }

    private var events: [CapturedKeyEvent] = []
    private let limits: Limits

    public init(limits: Limits = .init()) {
        self.limits = limits
    }

    public func append(_ event: CapturedKeyEvent) {
        events.append(event)
        prune(referenceTime: event.timestamp)
    }

    public func snapshot(now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> [CapturedKeyEvent] {
        prune(referenceTime: now)
        return events
    }

    public func clear() {
        events.removeAll(keepingCapacity: true)
    }

    public func invalidate(where predicate: (CapturedKeyEvent) -> Bool) {
        events.removeAll(where: predicate)
    }

    private func prune(referenceTime: TimeInterval) {
        let cutoff = referenceTime - limits.maxAge
        if let firstValidIndex = events.firstIndex(where: { $0.timestamp >= cutoff }) {
            if firstValidIndex > events.startIndex {
                events.removeSubrange(events.startIndex..<firstValidIndex)
            }
        } else if !events.isEmpty {
            events.removeAll(keepingCapacity: true)
        }

        if events.count > limits.maxCount {
            events.removeFirst(events.count - limits.maxCount)
        }
    }
}

import Foundation
import CoreGraphics

public struct CapturedKeyEvent: Sendable, Equatable {
    public let timestamp: TimeInterval
    public let keyCode: CGKeyCode
    public let flagsRawValue: UInt64
    /// Unicode projection attached to the event at capture time. This is used
    /// for detection/boundary analysis only. Replay always uses the physical
    /// virtual key code and flags instead of trusting this text projection.
    public let characters: String?
    public let sourcePID: pid_t
    public let focusIdentity: String?
    public let inputSourceID: String
    public let isSynthetic: Bool
    public let isRepeat: Bool

    public init(
        timestamp: TimeInterval,
        keyCode: CGKeyCode,
        flagsRawValue: UInt64,
        characters: String?,
        sourcePID: pid_t,
        focusIdentity: String?,
        inputSourceID: String,
        isSynthetic: Bool,
        isRepeat: Bool = false
    ) {
        self.timestamp = timestamp
        self.keyCode = keyCode
        self.flagsRawValue = flagsRawValue
        self.characters = characters
        self.sourcePID = sourcePID
        self.focusIdentity = focusIdentity
        self.inputSourceID = inputSourceID
        self.isSynthetic = isSynthetic
        self.isRepeat = isRepeat
    }

    public var flags: CGEventFlags {
        CGEventFlags(rawValue: flagsRawValue)
    }
}

public struct InputSourceEpoch: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let startedAt: TimeInterval
    public let inputSourceID: String
    public let sourcePID: pid_t
    public let focusIdentity: String?

    public init(
        id: UUID = UUID(),
        startedAt: TimeInterval,
        inputSourceID: String,
        sourcePID: pid_t,
        focusIdentity: String?
    ) {
        self.id = id
        self.startedAt = startedAt
        self.inputSourceID = inputSourceID
        self.sourcePID = sourcePID
        self.focusIdentity = focusIdentity
    }
}

public struct TypingBurst: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let epochID: UUID
    public let events: [CapturedKeyEvent]

    public init(id: UUID = UUID(), epochID: UUID, events: [CapturedKeyEvent]) {
        self.id = id
        self.epochID = epochID
        self.events = events
    }

    public var startedAt: TimeInterval? { events.first?.timestamp }
    public var endedAt: TimeInterval? { events.last?.timestamp }
}

public struct RecoveryCandidate: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let burst: TypingBurst
    public let sourceInputSourceID: String
    public let targetInputSourceID: String
    public let confidence: Double
    public let reason: String

    public init(
        id: UUID = UUID(),
        burst: TypingBurst,
        sourceInputSourceID: String,
        targetInputSourceID: String,
        confidence: Double,
        reason: String
    ) {
        self.id = id
        self.burst = burst
        self.sourceInputSourceID = sourceInputSourceID
        self.targetInputSourceID = targetInputSourceID
        self.confidence = confidence
        self.reason = reason
    }
}

public enum RecoverySupportLevel: String, Sendable, Codable {
    case fullRecovery
    case manualRecovery
    case suggestOnly
    case unsupported
}

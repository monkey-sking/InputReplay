import Foundation

public struct PreMutationSnapshot: Sendable, Equatable {
    public let createdAt: Date
    public let originalInputSourceID: String
    public let targetInputSourceID: String
    public let originalText: String?
    public let selectedRangeLocation: Int?
    public let selectedRangeLength: Int?
    public let rawEvents: [CapturedKeyEvent]
    public let restoreIsReliable: Bool

    public init(
        createdAt: Date = Date(),
        originalInputSourceID: String,
        targetInputSourceID: String,
        originalText: String?,
        selectedRangeLocation: Int?,
        selectedRangeLength: Int?,
        rawEvents: [CapturedKeyEvent],
        restoreIsReliable: Bool
    ) {
        self.createdAt = createdAt
        self.originalInputSourceID = originalInputSourceID
        self.targetInputSourceID = targetInputSourceID
        self.originalText = originalText
        self.selectedRangeLocation = selectedRangeLocation
        self.selectedRangeLength = selectedRangeLength
        self.rawEvents = rawEvents
        self.restoreIsReliable = restoreIsReliable
    }
}

public enum RecoveryTransactionState: Sendable, Equatable {
    case prepared
    case rollingBack
    case switchingInputSource
    case replaying
    case verifying
    case committed
    case restoring
    case restored
    case aborted(String)
}

public struct RecoveryTransaction: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let snapshot: PreMutationSnapshot
    public var state: RecoveryTransactionState

    public init(
        id: UUID = UUID(),
        snapshot: PreMutationSnapshot,
        state: RecoveryTransactionState = .prepared
    ) {
        self.id = id
        self.snapshot = snapshot
        self.state = state
    }

    public var mayPerformDestructiveMutation: Bool {
        snapshot.restoreIsReliable
    }
}

public enum MutationGate {
    /// System invariant: destructive user-visible mutation is forbidden unless
    /// a reliable restore plan was established before the mutation.
    public static func allowsDestructiveMutation(snapshot: PreMutationSnapshot?) -> Bool {
        snapshot?.restoreIsReliable == true
    }
}

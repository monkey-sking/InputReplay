import Foundation
import ApplicationServices

public enum RecoveryCoordinatorError: Error, Sendable, Equatable {
    case unsafeMutation
    case originalInputSourceUnavailable
    case targetInputSourceUnavailable
    case rollbackFailed
    case replayFailed
    case verificationFailed
    case restoreFailed
}

public struct RecoveryPlan: Sendable, Equatable {
    public let originalInputSourceID: String
    public let targetInputSourceID: String
    public let textSnapshot: AXTextSnapshot
    public let rawEvents: [CapturedKeyEvent]
    public let restoreIsReliable: Bool

    public init(
        originalInputSourceID: String,
        targetInputSourceID: String,
        textSnapshot: AXTextSnapshot,
        rawEvents: [CapturedKeyEvent],
        restoreIsReliable: Bool
    ) {
        self.originalInputSourceID = originalInputSourceID
        self.targetInputSourceID = targetInputSourceID
        self.textSnapshot = textSnapshot
        self.rawEvents = rawEvents
        self.restoreIsReliable = restoreIsReliable
    }

    public var preMutationSnapshot: PreMutationSnapshot {
        PreMutationSnapshot(
            originalInputSourceID: originalInputSourceID,
            targetInputSourceID: targetInputSourceID,
            originalText: textSnapshot.text,
            selectedRangeLocation: textSnapshot.rangeLocation,
            selectedRangeLength: textSnapshot.rangeLength,
            rawEvents: rawEvents,
            restoreIsReliable: restoreIsReliable
        )
    }
}

public protocol RecoveryTextEditing: Sendable {
    func replace(snapshot: AXTextSnapshot, with replacement: String) throws
    func replace(range: CFRange, with replacement: String) throws
}

extension AXTextEditor: RecoveryTextEditing {}

public protocol RecoveryInputSourceControlling: Sendable {
    @discardableResult
    func select(id: String) -> Bool
}

extension InputSourceController: RecoveryInputSourceControlling {}

public protocol RecoveryReplaying: Sendable {
    func replay(events: [CapturedKeyEvent], through targetInputSourceID: String) throws
}

extension ReplayEngine: RecoveryReplaying {
    public func replay(events: [CapturedKeyEvent], through targetInputSourceID: String) throws {
        try replay(events: events, through: targetInputSourceID, interKeyDelayMicroseconds: 1_500)
    }
}

public protocol RecoveryVerifying: Sendable {
    func verify(plan: RecoveryPlan) async -> Bool
}

/// Safe default: until a host/IME-specific verifier exists, recovery must not
/// be promoted to committed automatically.
public struct ConservativeRecoveryVerifier: RecoveryVerifying {
    public init() {}
    public func verify(plan: RecoveryPlan) async -> Bool { false }
}

public actor RecoveryCoordinator {
    private let textEditor: RecoveryTextEditing
    private let inputSources: RecoveryInputSourceControlling
    private let replayer: RecoveryReplaying
    private let verifier: RecoveryVerifying

    public private(set) var activeTransaction: RecoveryTransaction?
    public private(set) var lastRestorableTransaction: RecoveryTransaction?

    public init(
        textEditor: RecoveryTextEditing = AXTextEditor(),
        inputSources: RecoveryInputSourceControlling = InputSourceController(),
        replayer: RecoveryReplaying = ReplayEngine(),
        verifier: RecoveryVerifying = ConservativeRecoveryVerifier()
    ) {
        self.textEditor = textEditor
        self.inputSources = inputSources
        self.replayer = replayer
        self.verifier = verifier
    }

    /// Executes the destructive portion only when a reliable pre-mutation
    /// restore plan already exists. Verification failure triggers restoration.
    @discardableResult
    public func recover(_ plan: RecoveryPlan) async throws -> RecoveryTransaction {
        var transaction = RecoveryTransaction(snapshot: plan.preMutationSnapshot)
        guard transaction.mayPerformDestructiveMutation else {
            transaction.state = .aborted("No reliable restore plan")
            activeTransaction = transaction
            throw RecoveryCoordinatorError.unsafeMutation
        }

        activeTransaction = transaction

        do {
            transaction.state = .rollingBack
            activeTransaction = transaction
            try textEditor.replace(snapshot: plan.textSnapshot, with: "")

            transaction.state = .switchingInputSource
            activeTransaction = transaction
            guard inputSources.select(id: plan.targetInputSourceID) else {
                throw RecoveryCoordinatorError.targetInputSourceUnavailable
            }

            transaction.state = .replaying
            activeTransaction = transaction
            do {
                try replayer.replay(events: plan.rawEvents, through: plan.targetInputSourceID)
            } catch {
                throw RecoveryCoordinatorError.replayFailed
            }

            transaction.state = .verifying
            activeTransaction = transaction
            guard await verifier.verify(plan: plan) else {
                throw RecoveryCoordinatorError.verificationFailed
            }

            transaction.state = .committed
            activeTransaction = nil
            lastRestorableTransaction = transaction
            return transaction
        } catch {
            do {
                transaction = try restore(plan: plan, transaction: transaction)
                lastRestorableTransaction = nil
            } catch {
                transaction.state = .aborted("Recovery failed and restore also failed")
                activeTransaction = transaction
                throw RecoveryCoordinatorError.restoreFailed
            }

            activeTransaction = nil
            throw error
        }
    }

    /// Restores the pre-mutation text and original input source. This is the
    /// safety path for failed verification and for explicit user undo.
    @discardableResult
    public func restoreLast() throws -> RecoveryTransaction? {
        guard let transaction = lastRestorableTransaction else { return nil }
        let snapshot = transaction.snapshot
        guard
            let originalText = snapshot.originalText,
            let location = snapshot.selectedRangeLocation,
            let length = snapshot.selectedRangeLength
        else {
            throw RecoveryCoordinatorError.restoreFailed
        }

        let plan = RecoveryPlan(
            originalInputSourceID: snapshot.originalInputSourceID,
            targetInputSourceID: snapshot.targetInputSourceID,
            textSnapshot: AXTextSnapshot(text: originalText, rangeLocation: location, rangeLength: length),
            rawEvents: snapshot.rawEvents,
            restoreIsReliable: snapshot.restoreIsReliable
        )

        var restored = try restore(plan: plan, transaction: transaction)
        restored.state = .restored
        lastRestorableTransaction = nil
        return restored
    }

    private func restore(plan: RecoveryPlan, transaction: RecoveryTransaction) throws -> RecoveryTransaction {
        var transaction = transaction
        transaction.state = .restoring
        activeTransaction = transaction

        // After rollback the target range has length 0. After replay we cannot
        // safely infer the committed/composition length generically, so the
        // first verified host adapter must supply stronger restoration data
        // before automatic full recovery is enabled.
        let restoreRange = CFRange(location: plan.textSnapshot.rangeLocation, length: 0)
        try textEditor.replace(range: restoreRange, with: plan.textSnapshot.text)

        guard inputSources.select(id: plan.originalInputSourceID) else {
            throw RecoveryCoordinatorError.originalInputSourceUnavailable
        }

        transaction.state = .restored
        activeTransaction = transaction
        return transaction
    }
}

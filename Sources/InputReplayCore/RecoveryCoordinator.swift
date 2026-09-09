import Foundation
import ApplicationServices

public enum RecoveryCoordinatorError: Error, Sendable, Equatable {
    case unsafeMutation
    case originalInputSourceUnavailable
    case targetInputSourceUnavailable
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

public struct RecoveryVerificationResult: Sendable, Equatable {
    public let succeeded: Bool
    /// Exact range currently occupied by replay output. Required for safe
    /// rollback after replay because IME output length cannot be inferred from
    /// raw key count.
    public let replayOutputRange: CFRange?

    public init(succeeded: Bool, replayOutputRange: CFRange?) {
        self.succeeded = succeeded
        self.replayOutputRange = replayOutputRange
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
    func verify(plan: RecoveryPlan) async -> RecoveryVerificationResult
}

/// Safe default: unknown host/IME combinations cannot prove either successful
/// recovery or the exact replay-output range, so they are never auto-committed.
public struct ConservativeRecoveryVerifier: RecoveryVerifying {
    public init() {}
    public func verify(plan: RecoveryPlan) async -> RecoveryVerificationResult {
        RecoveryVerificationResult(succeeded: false, replayOutputRange: nil)
    }
}

public actor RecoveryCoordinator {
    private let textEditor: RecoveryTextEditing
    private let inputSources: RecoveryInputSourceControlling
    private let replayer: RecoveryReplaying
    private let verifier: RecoveryVerifying

    public private(set) var activeTransaction: RecoveryTransaction?
    public private(set) var lastRestorableTransaction: RecoveryTransaction?
    private var lastReplayOutputRange: CFRange?

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

    /// Executes destructive recovery only when the caller has already proved
    /// that a reliable restore path exists for this host/IME combination.
    @discardableResult
    public func recover(_ plan: RecoveryPlan) async throws -> RecoveryTransaction {
        var transaction = RecoveryTransaction(snapshot: plan.preMutationSnapshot)
        guard transaction.mayPerformDestructiveMutation else {
            transaction.state = .aborted("No reliable restore plan")
            activeTransaction = transaction
            throw RecoveryCoordinatorError.unsafeMutation
        }

        activeTransaction = transaction
        lastReplayOutputRange = nil

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
            let verification = await verifier.verify(plan: plan)
            lastReplayOutputRange = verification.replayOutputRange

            guard verification.succeeded else {
                throw RecoveryCoordinatorError.verificationFailed
            }
            guard verification.replayOutputRange != nil else {
                throw RecoveryCoordinatorError.unsafeMutation
            }

            transaction.state = .committed
            activeTransaction = nil
            lastRestorableTransaction = transaction
            return transaction
        } catch {
            // If replay already occurred, restoration is only safe when the
            // verifier identified the exact resulting text/composition range.
            let replayHadStarted = transaction.state == .replaying || transaction.state == .verifying
            if replayHadStarted && lastReplayOutputRange == nil {
                transaction.state = .aborted("Replay output range is unknown; refusing guessed restore")
                activeTransaction = transaction
                throw RecoveryCoordinatorError.restoreFailed
            }

            do {
                transaction = try restore(
                    plan: plan,
                    transaction: transaction,
                    replayOutputRange: lastReplayOutputRange
                )
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

    /// User-facing undo for a successfully verified recovery.
    @discardableResult
    public func restoreLast() throws -> RecoveryTransaction? {
        guard let transaction = lastRestorableTransaction else { return nil }
        let snapshot = transaction.snapshot
        guard
            let originalText = snapshot.originalText,
            let location = snapshot.selectedRangeLocation,
            let length = snapshot.selectedRangeLength,
            let replayOutputRange = lastReplayOutputRange
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

        var restored = try restore(
            plan: plan,
            transaction: transaction,
            replayOutputRange: replayOutputRange
        )
        restored.state = .restored
        lastRestorableTransaction = nil
        lastReplayOutputRange = nil
        return restored
    }

    private func restore(
        plan: RecoveryPlan,
        transaction: RecoveryTransaction,
        replayOutputRange: CFRange?
    ) throws -> RecoveryTransaction {
        var transaction = transaction
        transaction.state = .restoring
        activeTransaction = transaction

        let range: CFRange
        if let replayOutputRange {
            range = replayOutputRange
        } else {
            // Safe only before replay has produced unknown output.
            range = CFRange(location: plan.textSnapshot.rangeLocation, length: 0)
        }

        try textEditor.replace(range: range, with: plan.textSnapshot.text)

        guard inputSources.select(id: plan.originalInputSourceID) else {
            throw RecoveryCoordinatorError.originalInputSourceUnavailable
        }

        transaction.state = .restored
        activeTransaction = transaction
        return transaction
    }
}

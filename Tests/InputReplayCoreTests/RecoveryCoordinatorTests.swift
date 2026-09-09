import XCTest
import ApplicationServices
@testable import InputReplayCore

final class RecoveryCoordinatorTests: XCTestCase {
    func testUnsafePlanDoesNotMutate() async {
        let text = FakeTextEditor()
        let inputs = FakeInputSources()
        let replayer = FakeReplayer()
        let verifier = FakeVerifier(result: .init(succeeded: true, replayOutputRange: CFRange(location: 0, length: 2)))
        let coordinator = RecoveryCoordinator(
            textEditor: text,
            inputSources: inputs,
            replayer: replayer,
            verifier: verifier
        )

        let plan = RecoveryPlan(
            originalInputSourceID: "abc",
            targetInputSourceID: "pinyin",
            textSnapshot: AXTextSnapshot(text: "ceshi", rangeLocation: 0, rangeLength: 5),
            rawEvents: [makeEvent()],
            restoreIsReliable: false
        )

        do {
            _ = try await coordinator.recover(plan)
            XCTFail("Expected unsafe mutation rejection")
        } catch let error as RecoveryCoordinatorError {
            XCTAssertEqual(error, .unsafeMutation)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(text.operations, [])
        XCTAssertEqual(inputs.selectedIDs, [])
        XCTAssertEqual(replayer.replayCount, 0)
    }

    func testVerificationFailureWithKnownRangeRestoresOriginalTextAndInputSource() async {
        let text = FakeTextEditor()
        let inputs = FakeInputSources()
        let replayer = FakeReplayer()
        let verifier = FakeVerifier(
            result: .init(succeeded: false, replayOutputRange: CFRange(location: 10, length: 2))
        )
        let coordinator = RecoveryCoordinator(
            textEditor: text,
            inputSources: inputs,
            replayer: replayer,
            verifier: verifier
        )

        let plan = RecoveryPlan(
            originalInputSourceID: "abc",
            targetInputSourceID: "pinyin",
            textSnapshot: AXTextSnapshot(text: "ceshi", rangeLocation: 10, rangeLength: 5),
            rawEvents: [makeEvent()],
            restoreIsReliable: true
        )

        do {
            _ = try await coordinator.recover(plan)
            XCTFail("Expected verification failure")
        } catch let error as RecoveryCoordinatorError {
            XCTAssertEqual(error, .verificationFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(text.operations.count, 2)
        XCTAssertEqual(text.operations[0], .snapshotReplace(text: "", location: 10, length: 5))
        XCTAssertEqual(text.operations[1], .rangeReplace(text: "ceshi", location: 10, length: 2))
        XCTAssertEqual(inputs.selectedIDs, ["pinyin", "abc"])
        XCTAssertEqual(replayer.replayCount, 1)
    }

    func testVerificationFailureWithoutKnownRangeRefusesGuessedRestore() async {
        let text = FakeTextEditor()
        let inputs = FakeInputSources()
        let replayer = FakeReplayer()
        let verifier = FakeVerifier(result: .init(succeeded: false, replayOutputRange: nil))
        let coordinator = RecoveryCoordinator(
            textEditor: text,
            inputSources: inputs,
            replayer: replayer,
            verifier: verifier
        )

        let plan = RecoveryPlan(
            originalInputSourceID: "abc",
            targetInputSourceID: "pinyin",
            textSnapshot: AXTextSnapshot(text: "ceshi", rangeLocation: 10, rangeLength: 5),
            rawEvents: [makeEvent()],
            restoreIsReliable: true
        )

        do {
            _ = try await coordinator.recover(plan)
            XCTFail("Expected restore failure")
        } catch let error as RecoveryCoordinatorError {
            XCTAssertEqual(error, .restoreFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(text.operations, [.snapshotReplace(text: "", location: 10, length: 5)])
        XCTAssertEqual(inputs.selectedIDs, ["pinyin"])
        XCTAssertEqual(replayer.replayCount, 1)
    }

    private func makeEvent() -> CapturedKeyEvent {
        CapturedKeyEvent(
            timestamp: Date().timeIntervalSince1970,
            keyCode: 8,
            flagsRawValue: 0,
            characters: "c",
            sourcePID: 123,
            focusIdentity: "test-field",
            inputSourceID: "abc",
            isSynthetic: false
        )
    }
}

private final class FakeTextEditor: RecoveryTextEditing, @unchecked Sendable {
    enum Operation: Equatable {
        case snapshotReplace(text: String, location: Int, length: Int)
        case rangeReplace(text: String, location: Int, length: Int)
    }

    var operations: [Operation] = []

    func replace(snapshot: AXTextSnapshot, with replacement: String) throws {
        operations.append(.snapshotReplace(text: replacement, location: snapshot.rangeLocation, length: snapshot.rangeLength))
    }

    func replace(range: CFRange, with replacement: String) throws {
        operations.append(.rangeReplace(text: replacement, location: range.location, length: range.length))
    }
}

private final class FakeInputSources: RecoveryInputSourceControlling, @unchecked Sendable {
    var selectedIDs: [String] = []
    func select(id: String) -> Bool {
        selectedIDs.append(id)
        return true
    }
}

private final class FakeReplayer: RecoveryReplaying, @unchecked Sendable {
    var replayCount = 0
    func replay(events: [CapturedKeyEvent], through targetInputSourceID: String) throws {
        replayCount += 1
    }
}

private struct FakeVerifier: RecoveryVerifying {
    let result: RecoveryVerificationResult
    func verify(plan: RecoveryPlan) async -> RecoveryVerificationResult { result }
}

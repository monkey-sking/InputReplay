import XCTest
import ApplicationServices
@testable import InputReplayCore

final class RecoveryCoordinatorTests: XCTestCase {
    func testUnsafePlanDoesNotMutate() async {
        let text = FakeTextEditor()
        let inputs = FakeInputSources()
        let replayer = FakeReplayer()
        let verifier = FakeVerifier(result: true)
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
            rawEvents: [CapturedKeyEvent(timestamp: Date(), keyCode: 8, flags: [], isSynthetic: false)],
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

    func testVerificationFailureRestoresOriginalTextAndInputSource() async {
        let text = FakeTextEditor()
        let inputs = FakeInputSources()
        let replayer = FakeReplayer()
        let verifier = FakeVerifier(result: false)
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
            rawEvents: [CapturedKeyEvent(timestamp: Date(), keyCode: 8, flags: [], isSynthetic: false)],
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
        XCTAssertEqual(text.operations[1], .rangeReplace(text: "ceshi", location: 10, length: 0))
        XCTAssertEqual(inputs.selectedIDs, ["pinyin", "abc"])
        XCTAssertEqual(replayer.replayCount, 1)
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
    let result: Bool
    func verify(plan: RecoveryPlan) async -> Bool { result }
}

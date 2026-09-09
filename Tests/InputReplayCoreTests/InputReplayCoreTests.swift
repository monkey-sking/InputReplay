import XCTest
@testable import InputReplayCore

final class InputReplayCoreTests: XCTestCase {
    func testMutationGateRequiresReliableRestorePlan() {
        let unsafe = PreMutationSnapshot(
            originalInputSourceID: "source",
            targetInputSourceID: "target",
            originalText: "abc",
            selectedRangeLocation: 0,
            selectedRangeLength: 3,
            rawEvents: [],
            restoreIsReliable: false
        )

        let safe = PreMutationSnapshot(
            originalInputSourceID: "source",
            targetInputSourceID: "target",
            originalText: "abc",
            selectedRangeLocation: 0,
            selectedRangeLength: 3,
            rawEvents: [],
            restoreIsReliable: true
        )

        XCTAssertFalse(MutationGate.allowsDestructiveMutation(snapshot: nil))
        XCTAssertFalse(MutationGate.allowsDestructiveMutation(snapshot: unsafe))
        XCTAssertTrue(MutationGate.allowsDestructiveMutation(snapshot: safe))
    }

    func testUnknownIMEFailsClosed() async {
        let adapter = ConservativeUnknownIMEAdapter()
        let context = IMEContext(
            inputSourceID: "third.party.unknown",
            bundleIdentifier: nil,
            hostBundleIdentifier: "com.apple.TextEdit"
        )

        let capabilities = await adapter.capabilities(in: context)
        XCTAssertEqual(capabilities.supportLevel, .suggestOnly)
        XCTAssertFalse(capabilities.acceptsSyntheticReplay)
        XCTAssertFalse(capabilities.canRestoreReliably)
    }
}

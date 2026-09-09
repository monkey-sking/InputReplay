import XCTest
@testable import InputReplayCore

final class InputContextTrackerTests: XCTestCase {
    func testSourceSwitchCapturesPreviousBurstButDoesNotMutateAnything() async {
        let tracker = InputContextTracker(
            configuration: .init(burstIdleGap: 1, switchDebounce: 0.1, suggestionTTL: 3)
        )

        await tracker.ingest(event(at: 10.0, source: "abc", keyCode: 8))
        await tracker.ingest(event(at: 10.1, source: "abc", keyCode: 14))

        let signal = await tracker.inputSourceDidChange(to: "pinyin", at: 10.2)
        XCTAssertEqual(signal?.previousInputSourceID, "abc")
        XCTAssertEqual(signal?.newInputSourceID, "pinyin")
        XCTAssertEqual(signal?.previousBurst?.events.count, 2)
        XCTAssertNotNil(await tracker.pendingSuggestion(at: 10.3))
    }

    func testNewPhysicalTypingInvalidatesOldSuggestion() async {
        let tracker = InputContextTracker()
        await tracker.ingest(event(at: 10.0, source: "abc", keyCode: 8))
        _ = await tracker.inputSourceDidChange(to: "pinyin", at: 10.1)
        XCTAssertNotNil(await tracker.pendingSuggestion(at: 10.2))

        await tracker.ingest(event(at: 10.3, source: "pinyin", keyCode: 0))
        XCTAssertNil(await tracker.pendingSuggestion(at: 10.31))
    }

    func testSyntheticReplayDoesNotInvalidateSuggestion() async {
        let tracker = InputContextTracker()
        await tracker.ingest(event(at: 10.0, source: "abc", keyCode: 8))
        _ = await tracker.inputSourceDidChange(to: "pinyin", at: 10.1)

        await tracker.ingest(event(at: 10.2, source: "pinyin", keyCode: 8, synthetic: true))
        XCTAssertNotNil(await tracker.pendingSuggestion(at: 10.3))
    }

    func testRapidDuplicateSourceChangesAreDebounced() async {
        let tracker = InputContextTracker(
            configuration: .init(burstIdleGap: 1, switchDebounce: 0.2, suggestionTTL: 3)
        )
        await tracker.ingest(event(at: 10.0, source: "abc", keyCode: 8))
        let first = await tracker.inputSourceDidChange(to: "pinyin", at: 10.2)
        let duplicate = await tracker.inputSourceDidChange(to: "abc", at: 10.25)

        XCTAssertNotNil(first)
        XCTAssertNil(duplicate)
        XCTAssertEqual((await tracker.epoch())?.inputSourceID, "pinyin")
    }

    func testIdleGapStartsNewBurstWithinSameEpoch() async {
        let tracker = InputContextTracker(
            configuration: .init(burstIdleGap: 1.0, switchDebounce: 0.1, suggestionTTL: 3)
        )
        await tracker.ingest(event(at: 10.0, source: "abc", keyCode: 8))
        await tracker.ingest(event(at: 12.0, source: "abc", keyCode: 14))

        let signal = await tracker.inputSourceDidChange(to: "pinyin", at: 12.1)
        XCTAssertEqual(signal?.previousBurst?.events.count, 1)
        XCTAssertEqual(signal?.previousBurst?.events.first?.keyCode, 14)
    }

    func testLifecycleBoundaryClearsSensitiveRecentState() async {
        let tracker = InputContextTracker()
        await tracker.ingest(event(at: 10.0, source: "abc", keyCode: 8))
        _ = await tracker.inputSourceDidChange(to: "pinyin", at: 10.1)

        await tracker.invalidateForLifecycleBoundary()

        XCTAssertNil(await tracker.pendingSuggestion(at: 10.2))
        XCTAssertNil(await tracker.epoch())
    }

    private func event(
        at timestamp: TimeInterval,
        source: String,
        keyCode: CGKeyCode,
        synthetic: Bool = false
    ) -> CapturedKeyEvent {
        CapturedKeyEvent(
            timestamp: timestamp,
            keyCode: keyCode,
            flagsRawValue: 0,
            characters: nil,
            sourcePID: 123,
            focusIdentity: "field",
            inputSourceID: source,
            isSynthetic: synthetic
        )
    }
}

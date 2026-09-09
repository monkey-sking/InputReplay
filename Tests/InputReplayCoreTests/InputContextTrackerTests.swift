import XCTest
import CoreGraphics
@testable import InputReplayCore

final class InputContextTrackerTests: XCTestCase {
    func testSourceSwitchCapturesPreviousBurstButDoesNotMutateAnything() async {
        let tracker = InputContextTracker(
            configuration: .init(burstIdleGap: 1, switchDebounce: 0.1, suggestionTTL: 3)
        )

        await tracker.ingest(event(at: 10.0, source: "abc", keyCode: 8))
        await tracker.ingest(event(at: 10.1, source: "abc", keyCode: 14))

        let signal = await tracker.inputSourceDidChange(
            to: "pinyin",
            at: 10.2,
            sourcePID: 123,
            focusIdentity: "field"
        )
        let pending = await tracker.pendingSuggestion(at: 10.3)
        XCTAssertEqual(signal?.previousInputSourceID, "abc")
        XCTAssertEqual(signal?.newInputSourceID, "pinyin")
        XCTAssertEqual(signal?.previousBurst?.events.count, 2)
        XCTAssertNotNil(pending)
    }

    func testNewPhysicalTypingInvalidatesOldSuggestion() async {
        let tracker = InputContextTracker()
        await tracker.ingest(event(at: 10.0, source: "abc", keyCode: 8))
        _ = await tracker.inputSourceDidChange(
            to: "pinyin",
            at: 10.1,
            sourcePID: 123,
            focusIdentity: "field"
        )
        let beforeTyping = await tracker.pendingSuggestion(at: 10.2)
        XCTAssertNotNil(beforeTyping)

        await tracker.ingest(event(at: 10.3, source: "pinyin", keyCode: 0))
        let afterTyping = await tracker.pendingSuggestion(at: 10.31)
        XCTAssertNil(afterTyping)
    }

    func testSyntheticReplayDoesNotInvalidateSuggestion() async {
        let tracker = InputContextTracker()
        await tracker.ingest(event(at: 10.0, source: "abc", keyCode: 8))
        _ = await tracker.inputSourceDidChange(
            to: "pinyin",
            at: 10.1,
            sourcePID: 123,
            focusIdentity: "field"
        )

        await tracker.ingest(event(at: 10.2, source: "pinyin", keyCode: 8, synthetic: true))
        let pending = await tracker.pendingSuggestion(at: 10.3)
        XCTAssertNotNil(pending)
    }

    func testRapidDuplicateSourceChangesAreDebounced() async {
        let tracker = InputContextTracker(
            configuration: .init(burstIdleGap: 1, switchDebounce: 0.2, suggestionTTL: 3)
        )
        await tracker.ingest(event(at: 10.0, source: "abc", keyCode: 8))
        let first = await tracker.inputSourceDidChange(
            to: "pinyin",
            at: 10.2,
            sourcePID: 123,
            focusIdentity: "field"
        )
        let duplicate = await tracker.inputSourceDidChange(
            to: "abc",
            at: 10.25,
            sourcePID: 123,
            focusIdentity: "field"
        )
        let epoch = await tracker.epoch()

        XCTAssertNotNil(first)
        XCTAssertNil(duplicate)
        XCTAssertEqual(epoch?.inputSourceID, "pinyin")
    }

    func testIdleGapStartsNewBurstWithinSameEpoch() async {
        let tracker = InputContextTracker(
            configuration: .init(burstIdleGap: 1.0, switchDebounce: 0.1, suggestionTTL: 3)
        )
        await tracker.ingest(event(at: 10.0, source: "abc", keyCode: 8))
        await tracker.ingest(event(at: 12.0, source: "abc", keyCode: 14))

        let signal = await tracker.inputSourceDidChange(
            to: "pinyin",
            at: 12.1,
            sourcePID: 123,
            focusIdentity: "field"
        )
        XCTAssertEqual(signal?.previousBurst?.events.count, 1)
        XCTAssertEqual(signal?.previousBurst?.events.first?.keyCode, 14)
    }

    func testFocusChangePreventsCrossFieldBurstRecovery() async {
        let tracker = InputContextTracker()
        await tracker.ingest(event(at: 10.0, source: "abc", keyCode: 8, focus: "field-A"))
        await tracker.ingest(event(at: 10.1, source: "abc", keyCode: 14, focus: "field-A"))

        // Same input source, different focused AX element: the previous field's
        // burst must be discarded before collecting input in the new field.
        await tracker.ingest(event(at: 10.2, source: "abc", keyCode: 0, focus: "field-B"))
        let signal = await tracker.inputSourceDidChange(
            to: "pinyin",
            at: 10.3,
            sourcePID: 123,
            focusIdentity: "field-B"
        )

        XCTAssertEqual(signal?.previousBurst?.events.count, 1)
        XCTAssertEqual(signal?.previousBurst?.events.first?.focusIdentity, "field-B")
    }

    func testFocusMovedBeforeSourceSwitchDropsOldBurst() async {
        let tracker = InputContextTracker()
        await tracker.ingest(event(at: 10.0, source: "abc", keyCode: 8, focus: "field-A"))
        await tracker.ingest(event(at: 10.1, source: "abc", keyCode: 14, focus: "field-A"))

        // The user clicks field B and changes input source before typing there.
        // No event from field B exists yet, so inputSourceDidChange itself must
        // compare the current focus and refuse to surface field A's burst.
        let signal = await tracker.inputSourceDidChange(
            to: "pinyin",
            at: 10.2,
            sourcePID: 123,
            focusIdentity: "field-B"
        )
        let pending = await tracker.pendingSuggestion(at: 10.21)
        let epoch = await tracker.epoch()

        XCTAssertNil(signal)
        XCTAssertNil(pending)
        XCTAssertEqual(epoch?.inputSourceID, "pinyin")
        XCTAssertEqual(epoch?.focusIdentity, "field-B")
    }

    func testProcessChangePreventsCrossAppBurstRecovery() async {
        let tracker = InputContextTracker()
        await tracker.ingest(event(at: 10.0, source: "abc", keyCode: 8, pid: 100, focus: "field"))
        await tracker.ingest(event(at: 10.1, source: "abc", keyCode: 14, pid: 200, focus: "field"))
        let signal = await tracker.inputSourceDidChange(
            to: "pinyin",
            at: 10.2,
            sourcePID: 200,
            focusIdentity: "field"
        )

        XCTAssertEqual(signal?.previousBurst?.events.count, 1)
        XCTAssertEqual(signal?.previousBurst?.events.first?.sourcePID, 200)
    }

    func testAppMovedBeforeSourceSwitchDropsOldBurst() async {
        let tracker = InputContextTracker()
        await tracker.ingest(event(at: 10.0, source: "abc", keyCode: 8, pid: 100, focus: "field-A"))

        let signal = await tracker.inputSourceDidChange(
            to: "pinyin",
            at: 10.2,
            sourcePID: 200,
            focusIdentity: "field-B"
        )
        let pending = await tracker.pendingSuggestion(at: 10.21)

        XCTAssertNil(signal)
        XCTAssertNil(pending)
    }

    func testLifecycleBoundaryClearsSensitiveRecentState() async {
        let tracker = InputContextTracker()
        await tracker.ingest(event(at: 10.0, source: "abc", keyCode: 8))
        _ = await tracker.inputSourceDidChange(
            to: "pinyin",
            at: 10.1,
            sourcePID: 123,
            focusIdentity: "field"
        )

        await tracker.invalidateForLifecycleBoundary()

        let pending = await tracker.pendingSuggestion(at: 10.2)
        let epoch = await tracker.epoch()
        XCTAssertNil(pending)
        XCTAssertNil(epoch)
    }

    private func event(
        at timestamp: TimeInterval,
        source: String,
        keyCode: CGKeyCode,
        pid: pid_t = 123,
        focus: String = "field",
        synthetic: Bool = false
    ) -> CapturedKeyEvent {
        CapturedKeyEvent(
            timestamp: timestamp,
            keyCode: keyCode,
            flagsRawValue: 0,
            characters: nil,
            sourcePID: pid,
            focusIdentity: focus,
            inputSourceID: source,
            isSynthetic: synthetic
        )
    }
}

import XCTest
import CoreGraphics
@testable import InputReplayCore

final class SmokeReplayPlannerTests: XCTestCase {
    func testAllowsSimplePrintableBurstWhenFocusIsUnchanged() throws {
        let events = [
            event(keyCode: 8, characters: "c"),
            event(keyCode: 14, characters: "e"),
            event(keyCode: 49, characters: " ")
        ]

        let plan = try SmokeReplayPlanner.makePlan(
            events: events,
            currentFocus: focus()
        )

        XCTAssertEqual(plan.events, events)
        XCTAssertEqual(plan.sourceProcessID, 123)
        XCTAssertEqual(plan.focusIdentity, "123:field-A")
    }

    func testRejectsBackspace() {
        XCTAssertThrowsError(
            try SmokeReplayPlanner.makePlan(
                events: [event(keyCode: 51, characters: nil)],
                currentFocus: focus()
            )
        ) { error in
            XCTAssertEqual(error as? SmokeReplayRejection, .destructiveKey(51))
        }
    }

    func testRejectsCommandShortcut() {
        XCTAssertThrowsError(
            try SmokeReplayPlanner.makePlan(
                events: [event(keyCode: 9, characters: "v", flags: .maskCommand)],
                currentFocus: focus()
            )
        ) { error in
            XCTAssertEqual(error as? SmokeReplayRejection, .commandModifier)
        }
    }

    func testRejectsControlShortcut() {
        XCTAssertThrowsError(
            try SmokeReplayPlanner.makePlan(
                events: [event(keyCode: 15, characters: "r", flags: .maskControl)],
                currentFocus: focus()
            )
        ) { error in
            XCTAssertEqual(error as? SmokeReplayRejection, .controlModifier)
        }
    }

    func testRejectsRepeat() {
        XCTAssertThrowsError(
            try SmokeReplayPlanner.makePlan(
                events: [event(keyCode: 8, characters: "c", repeatKey: true)],
                currentFocus: focus()
            )
        ) { error in
            XCTAssertEqual(error as? SmokeReplayRejection, .repeatedKey)
        }
    }

    func testRejectsChangedFocusedElement() {
        XCTAssertThrowsError(
            try SmokeReplayPlanner.makePlan(
                events: [event(keyCode: 8, characters: "c")],
                currentFocus: focus(identity: "123:field-B")
            )
        ) { error in
            XCTAssertEqual(error as? SmokeReplayRejection, .focusChanged)
        }
    }

    func testRejectsChangedProcess() {
        XCTAssertThrowsError(
            try SmokeReplayPlanner.makePlan(
                events: [event(keyCode: 8, characters: "c")],
                currentFocus: FocusedInputContextSnapshot(
                    processID: 999,
                    focusIdentity: "999:field-A",
                    role: "AXTextArea",
                    subrole: nil,
                    isSecure: false
                )
            )
        ) { error in
            XCTAssertEqual(error as? SmokeReplayRejection, .focusChanged)
        }
    }

    func testRejectsSecureFocus() {
        XCTAssertThrowsError(
            try SmokeReplayPlanner.makePlan(
                events: [event(keyCode: 8, characters: "c")],
                currentFocus: focus(secure: true)
            )
        ) { error in
            XCTAssertEqual(error as? SmokeReplayRejection, .secureFocus)
        }
    }

    private func focus(
        identity: String = "123:field-A",
        secure: Bool = false
    ) -> FocusedInputContextSnapshot {
        FocusedInputContextSnapshot(
            processID: 123,
            focusIdentity: identity,
            role: "AXTextArea",
            subrole: nil,
            isSecure: secure
        )
    }

    private func event(
        keyCode: CGKeyCode,
        characters: String?,
        flags: CGEventFlags = [],
        repeatKey: Bool = false
    ) -> CapturedKeyEvent {
        CapturedKeyEvent(
            timestamp: 10,
            keyCode: keyCode,
            flagsRawValue: flags.rawValue,
            characters: characters,
            sourcePID: 123,
            focusIdentity: "123:field-A",
            inputSourceID: "abc",
            isSynthetic: false,
            isRepeat: repeatKey
        )
    }
}

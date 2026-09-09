import XCTest
import CoreGraphics
import Carbon
@testable import InputReplayCore

final class TypingProjectionTests: XCTestCase {
    func testPinyinLikePolicyKeepsSpacesButSplitsAtPunctuation() {
        let events = Array("hello,wo jintian").enumerated().map { index, character in
            event(at: Double(index), keyCode: 0, characters: String(character))
        }

        let projection = TypingProjector.project(events)
        XCTAssertTrue(projection.isTextProjectionReliable)
        XCTAssertEqual(projection.visibleTextEstimate, "hello,wo jintian")
        XCTAssertEqual(projection.recoverableSuffix(using: .pinyinLike), "wo jintian")
        XCTAssertEqual(projection.recoverableSuffix(using: .codeIMEConservative), "jintian")
    }

    func testBackspaceUpdatesVisibleProjectionWithoutDiscardingReplayHistory() {
        let events = [
            event(at: 1, keyCode: 0, characters: "a"),
            event(at: 2, keyCode: 0, characters: "b"),
            event(at: 3, keyCode: CGKeyCode(kVK_Delete), characters: nil),
            event(at: 4, keyCode: 0, characters: "c")
        ]

        let projection = TypingProjector.project(events)
        XCTAssertEqual(projection.visibleTextEstimate, "ac")
        XCTAssertTrue(projection.hadBackspace)
        XCTAssertEqual(events.count, 4, "Projection must not rewrite the raw replay history")
    }

    func testCommandShortcutMakesEventOnlyTextProjectionUnsafe() {
        let commandV = CapturedKeyEvent(
            timestamp: 1,
            keyCode: 9,
            flagsRawValue: CGEventFlags.maskCommand.rawValue,
            characters: "v",
            sourcePID: 1,
            focusIdentity: "field",
            inputSourceID: "abc",
            isSynthetic: false
        )

        let projection = TypingProjector.project([commandV])
        XCTAssertFalse(projection.isTextProjectionReliable)
        XCTAssertNil(projection.recoverableSuffix(using: .pinyinLike))
    }

    func testReturnIsStrongBoundaryRegardlessOfIMEPolicy() {
        let events = [
            event(at: 1, keyCode: 0, characters: "a"),
            event(at: 2, keyCode: CGKeyCode(kVK_Return), characters: "\n"),
            event(at: 3, keyCode: 0, characters: "b")
        ]

        let projection = TypingProjector.project(events)
        XCTAssertEqual(projection.recoverableSuffix(using: .pinyinLike), "b")
        XCTAssertEqual(projection.recoverableSuffix(using: .codeIMEConservative), "b")
    }

    private func event(
        at timestamp: TimeInterval,
        keyCode: CGKeyCode,
        characters: String?
    ) -> CapturedKeyEvent {
        CapturedKeyEvent(
            timestamp: timestamp,
            keyCode: keyCode,
            flagsRawValue: 0,
            characters: characters,
            sourcePID: 1,
            focusIdentity: "field",
            inputSourceID: "abc",
            isSynthetic: false
        )
    }
}

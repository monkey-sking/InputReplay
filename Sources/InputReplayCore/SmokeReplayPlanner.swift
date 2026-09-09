import Foundation
import CoreGraphics

public enum SmokeReplayRejection: Error, Sendable, Equatable, CustomStringConvertible {
    case noEvents
    case syntheticEvent
    case repeatedKey
    case destructiveKey(CGKeyCode)
    case commandModifier
    case controlModifier
    case functionModifier
    case unsupportedModifier
    case nonPrintableKey(CGKeyCode)
    case multilineOrControlCharacter
    case mixedProcess
    case mixedFocus
    case focusUnavailable
    case focusChanged
    case secureFocus

    public var description: String {
        switch self {
        case .noEvents: return "No replayable events"
        case .syntheticEvent: return "Synthetic events are not eligible for the smoke replay"
        case .repeatedKey: return "Key-repeat events are excluded from the smoke replay"
        case .destructiveKey(let code): return "Destructive/navigation key is not allowed (keyCode=\(code))"
        case .commandModifier: return "Command-modified shortcuts are not allowed"
        case .controlModifier: return "Control-modified shortcuts are not allowed"
        case .functionModifier: return "Function-modified shortcuts are not allowed"
        case .unsupportedModifier: return "This modifier combination is not allowed in append-only smoke replay"
        case .nonPrintableKey(let code): return "Non-printable key is not allowed (keyCode=\(code))"
        case .multilineOrControlCharacter: return "Newlines, tabs, and control characters are not allowed"
        case .mixedProcess: return "Events span more than one process"
        case .mixedFocus: return "Events span more than one focused element"
        case .focusUnavailable: return "Current focused element cannot be verified"
        case .focusChanged: return "Focused element changed after the burst was captured"
        case .secureFocus: return "Secure input is active"
        }
    }
}

public struct SmokeReplayPlan: Sendable, Equatable {
    public let events: [CapturedKeyEvent]
    public let sourceProcessID: pid_t
    public let focusIdentity: String

    public init(events: [CapturedKeyEvent], sourceProcessID: pid_t, focusIdentity: String) {
        self.events = events
        self.sourceProcessID = sourceProcessID
        self.focusIdentity = focusIdentity
    }
}

/// Builds a deliberately narrow append-only replay plan for the first real-Mac
/// technical gate. It is *not* the normal recovery planner.
///
/// The smoke probe must never replay Backspace/Delete/navigation/shortcut keys
/// into a live document. If a burst cannot be proven append-only, it is rejected.
public enum SmokeReplayPlanner {
    // ANSI virtual key codes that can alter existing content, commit/cancel an
    // IME session, or move the insertion point. Keep the deny-list explicit.
    private static let deniedKeyCodes: Set<CGKeyCode> = [
        36,  // Return
        48,  // Tab
        51,  // Delete / Backspace
        53,  // Escape
        71,  // Keypad Clear
        76,  // Keypad Enter
        114, // Help / Insert on some keyboards
        115, // Home
        116, // Page Up
        117, // Forward Delete
        119, // End
        121, // Page Down
        123, // Left
        124, // Right
        125, // Down
        126  // Up
    ]

    private static let permittedModifierMask: CGEventFlags = [
        .maskShift,
        .maskAlphaShift
    ]

    public static func makePlan(
        events: [CapturedKeyEvent],
        currentFocus: FocusedInputContextSnapshot?
    ) throws -> SmokeReplayPlan {
        let physical = events.filter { !$0.isSynthetic }
        guard !physical.isEmpty else { throw SmokeReplayRejection.noEvents }
        guard physical.count == events.count else { throw SmokeReplayRejection.syntheticEvent }
        guard !physical.contains(where: \.isRepeat) else { throw SmokeReplayRejection.repeatedKey }

        let first = physical[0]
        guard first.sourcePID != 0 else { throw SmokeReplayRejection.focusUnavailable }
        guard let capturedFocus = first.focusIdentity, !capturedFocus.isEmpty else {
            throw SmokeReplayRejection.focusUnavailable
        }

        guard physical.allSatisfy({ $0.sourcePID == first.sourcePID }) else {
            throw SmokeReplayRejection.mixedProcess
        }
        guard physical.allSatisfy({ $0.focusIdentity == capturedFocus }) else {
            throw SmokeReplayRejection.mixedFocus
        }

        for event in physical {
            if deniedKeyCodes.contains(event.keyCode) {
                throw SmokeReplayRejection.destructiveKey(event.keyCode)
            }

            let flags = event.flags
            if flags.contains(.maskCommand) { throw SmokeReplayRejection.commandModifier }
            if flags.contains(.maskControl) { throw SmokeReplayRejection.controlModifier }
            if flags.contains(.maskSecondaryFn) { throw SmokeReplayRejection.functionModifier }

            let relevant = flags.intersection([
                .maskCommand,
                .maskShift,
                .maskAlphaShift,
                .maskAlternate,
                .maskControl,
                .maskSecondaryFn,
                .maskNumericPad,
                .maskHelp
            ])
            if !relevant.subtracting(permittedModifierMask).isEmpty {
                throw SmokeReplayRejection.unsupportedModifier
            }

            guard let characters = event.characters, !characters.isEmpty else {
                throw SmokeReplayRejection.nonPrintableKey(event.keyCode)
            }
            if characters.unicodeScalars.contains(where: {
                CharacterSet.controlCharacters.contains($0) || $0 == "\n" || $0 == "\r" || $0 == "\t"
            }) {
                throw SmokeReplayRejection.multilineOrControlCharacter
            }
        }

        guard let currentFocus else { throw SmokeReplayRejection.focusUnavailable }
        guard !currentFocus.isSecure else { throw SmokeReplayRejection.secureFocus }
        guard currentFocus.processID == first.sourcePID,
              currentFocus.focusIdentity == capturedFocus
        else {
            throw SmokeReplayRejection.focusChanged
        }

        return SmokeReplayPlan(
            events: physical,
            sourceProcessID: first.sourcePID,
            focusIdentity: capturedFocus
        )
    }
}

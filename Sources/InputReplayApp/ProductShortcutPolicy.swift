import CoreGraphics
import InputReplayCore

enum ProductShortcutPolicy {
    /// Experimental append-only replay shortcut: Control + Option + R.
    static func shouldCapture(_ event: CapturedKeyEvent) -> Bool {
        !isExperimentalReplayShortcut(event)
    }

    static func isExperimentalReplayShortcut(_ event: CapturedKeyEvent) -> Bool {
        guard event.keyCode == 15 else { return false } // ANSI R
        let flags = event.flags
        let relevant = flags.intersection([
            .maskCommand,
            .maskShift,
            .maskAlternate,
            .maskControl,
            .maskSecondaryFn
        ])
        return relevant == [.maskControl, .maskAlternate]
    }
}

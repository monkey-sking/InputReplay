import Foundation
import CoreGraphics

public enum ReplayEngineError: Error, Sendable, Equatable {
    case inputSourceSelectionFailed(String)
    case noReplayableEvents
}

public enum SyntheticEventMarker {
    // Used to distinguish our own replay from physical user input in the event tap.
    public static let value: Int64 = 0x4952504C // "IRPL"
}

public final class ReplayEngine: @unchecked Sendable {
    private let inputSources: InputSourceController

    public init(inputSources: InputSourceController = InputSourceController()) {
        self.inputSources = inputSources
    }

    public func replay(
        events: [CapturedKeyEvent],
        through targetInputSourceID: String,
        sourceSettleDelayMicroseconds: useconds_t = 40_000,
        interKeyDelayMicroseconds: useconds_t = 1_500
    ) throws {
        let replayable = events.filter { !$0.isSynthetic }
        guard !replayable.isEmpty else { throw ReplayEngineError.noReplayableEvents }

        guard inputSources.select(id: targetInputSourceID) else {
            throw ReplayEngineError.inputSourceSelectionFailed(targetInputSourceID)
        }

        // CJK IMEs can need a short stabilization window after TIS selection.
        // Keep this explicit and configurable so compatibility probes can tune
        // the value per host/IME tuple instead of relying on race-prone replay.
        if sourceSettleDelayMicroseconds > 0 {
            usleep(sourceSettleDelayMicroseconds)
        }

        for captured in replayable {
            guard let down = CGEvent(
                keyboardEventSource: nil,
                virtualKey: captured.keyCode,
                keyDown: true
            ), let up = CGEvent(
                keyboardEventSource: nil,
                virtualKey: captured.keyCode,
                keyDown: false
            ) else {
                continue
            }

            down.flags = captured.flags
            up.flags = captured.flags
            down.setIntegerValueField(.eventSourceUserData, value: SyntheticEventMarker.value)
            up.setIntegerValueField(.eventSourceUserData, value: SyntheticEventMarker.value)

            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
            usleep(interKeyDelayMicroseconds)
        }
    }
}

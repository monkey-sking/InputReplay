import Foundation

public enum AppleInputMethodKind: String, Sendable, Codable {
    case abc
    case pinyin
    case wubi
}

/// Apple adapters are configured with the actual input source ID discovered on
/// the current Mac. We deliberately avoid assuming that undocumented source IDs
/// are stable across macOS releases/locales.
public struct AppleInputMethodAdapter: InputMethodAdapter {
    public let id: String
    public let kind: AppleInputMethodKind
    public let inputSourceID: String

    public init(kind: AppleInputMethodKind, inputSourceID: String) {
        self.kind = kind
        self.inputSourceID = inputSourceID
        self.id = "apple.\(kind.rawValue).\(inputSourceID)"
    }

    public func matches(_ context: IMEContext) -> Bool {
        context.inputSourceID == inputSourceID
    }

    public func capabilities(in context: IMEContext) async -> IMECapabilities {
        guard matches(context) else { return IMECapabilities() }

        // These are intentionally conservative defaults. Synthetic replay,
        // restoration, and verification are promoted only after a real-host
        // compatibility probe records observed evidence.
        return IMECapabilities(
            canSelectInputSource: true,
            canObserveInternalMode: kind == .abc,
            canControlInternalMode: kind == .abc,
            acceptsSyntheticReplay: false,
            canCancelCompositionSafely: kind == .abc,
            canRestoreReliably: kind == .abc,
            canVerifyRecovery: false
        )
    }

    public func score(candidate: RecoveryCandidate, context: IMEContext) async -> Double {
        guard matches(context) else { return 0 }
        switch kind {
        case .abc:
            return candidate.confidence
        case .pinyin:
            // Pinyin segmentation/scoring will be added behind this adapter;
            // replay itself still goes through the user's real IME.
            return candidate.confidence
        case .wubi:
            // Four-code shapes are a feature, never a hard recovery boundary.
            return candidate.confidence
        }
    }
}

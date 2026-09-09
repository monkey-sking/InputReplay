import Foundation

public struct IMECapabilities: Sendable, Equatable {
    public var canSelectInputSource: Bool
    public var canObserveInternalMode: Bool
    public var canControlInternalMode: Bool
    public var acceptsSyntheticReplay: Bool
    public var canCancelCompositionSafely: Bool
    public var canRestoreReliably: Bool
    public var canVerifyRecovery: Bool

    public init(
        canSelectInputSource: Bool = false,
        canObserveInternalMode: Bool = false,
        canControlInternalMode: Bool = false,
        acceptsSyntheticReplay: Bool = false,
        canCancelCompositionSafely: Bool = false,
        canRestoreReliably: Bool = false,
        canVerifyRecovery: Bool = false
    ) {
        self.canSelectInputSource = canSelectInputSource
        self.canObserveInternalMode = canObserveInternalMode
        self.canControlInternalMode = canControlInternalMode
        self.acceptsSyntheticReplay = acceptsSyntheticReplay
        self.canCancelCompositionSafely = canCancelCompositionSafely
        self.canRestoreReliably = canRestoreReliably
        self.canVerifyRecovery = canVerifyRecovery
    }

    public var supportLevel: RecoverySupportLevel {
        guard canSelectInputSource else { return .suggestOnly }
        guard acceptsSyntheticReplay else { return .suggestOnly }
        guard canRestoreReliably else { return .manualRecovery }
        guard canVerifyRecovery else { return .manualRecovery }
        return .fullRecovery
    }
}

public struct IMEContext: Sendable, Equatable {
    public let inputSourceID: String
    public let bundleIdentifier: String?
    public let hostBundleIdentifier: String?

    public init(inputSourceID: String, bundleIdentifier: String?, hostBundleIdentifier: String?) {
        self.inputSourceID = inputSourceID
        self.bundleIdentifier = bundleIdentifier
        self.hostBundleIdentifier = hostBundleIdentifier
    }
}

public protocol InputMethodAdapter: Sendable {
    var id: String { get }
    func matches(_ context: IMEContext) -> Bool
    func capabilities(in context: IMEContext) async -> IMECapabilities
    func score(candidate: RecoveryCandidate, context: IMEContext) async -> Double
}

public struct ConservativeUnknownIMEAdapter: InputMethodAdapter {
    public let id = "unknown"

    public init() {}

    public func matches(_ context: IMEContext) -> Bool { true }

    public func capabilities(in context: IMEContext) async -> IMECapabilities {
        // Unknown third-party IME state is never guessed.
        IMECapabilities()
    }

    public func score(candidate: RecoveryCandidate, context: IMEContext) async -> Double {
        0
    }
}

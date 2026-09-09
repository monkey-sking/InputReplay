import Foundation

public enum CompatibilityEvidenceLevel: String, Sendable, Codable, CaseIterable {
    case prepared
    case observed
    case verified
}

public enum RecoveryDirection: String, Sendable, Codable, CaseIterable {
    case latinToIME
    case imeToLatin
}

public struct IMECompatibilityKey: Hashable, Sendable, Codable {
    public let inputSourceID: String
    public let hostBundleIdentifier: String
    public let direction: RecoveryDirection

    public init(
        inputSourceID: String,
        hostBundleIdentifier: String,
        direction: RecoveryDirection
    ) {
        self.inputSourceID = inputSourceID
        self.hostBundleIdentifier = hostBundleIdentifier
        self.direction = direction
    }
}

public struct IMECompatibilityEvidence: Sendable, Codable {
    public let key: IMECompatibilityKey
    public let level: CompatibilityEvidenceLevel
    public let capabilities: IMECapabilitiesSnapshot
    public let macOSVersion: String?
    public let appVersion: String?
    public let notes: String?

    public init(
        key: IMECompatibilityKey,
        level: CompatibilityEvidenceLevel,
        capabilities: IMECapabilitiesSnapshot,
        macOSVersion: String? = nil,
        appVersion: String? = nil,
        notes: String? = nil
    ) {
        self.key = key
        self.level = level
        self.capabilities = capabilities
        self.macOSVersion = macOSVersion
        self.appVersion = appVersion
        self.notes = notes
    }
}

/// Codable transport/storage form. The runtime IMECapabilities type remains
/// intentionally lightweight and implementation-focused.
public struct IMECapabilitiesSnapshot: Sendable, Codable, Equatable {
    public let canSelectInputSource: Bool
    public let canObserveInternalMode: Bool
    public let canControlInternalMode: Bool
    public let acceptsSyntheticReplay: Bool
    public let canCancelCompositionSafely: Bool
    public let canRestoreReliably: Bool
    public let canVerifyRecovery: Bool

    public init(_ capabilities: IMECapabilities) {
        self.canSelectInputSource = capabilities.canSelectInputSource
        self.canObserveInternalMode = capabilities.canObserveInternalMode
        self.canControlInternalMode = capabilities.canControlInternalMode
        self.acceptsSyntheticReplay = capabilities.acceptsSyntheticReplay
        self.canCancelCompositionSafely = capabilities.canCancelCompositionSafely
        self.canRestoreReliably = capabilities.canRestoreReliably
        self.canVerifyRecovery = capabilities.canVerifyRecovery
    }

    public var runtime: IMECapabilities {
        IMECapabilities(
            canSelectInputSource: canSelectInputSource,
            canObserveInternalMode: canObserveInternalMode,
            canControlInternalMode: canControlInternalMode,
            acceptsSyntheticReplay: acceptsSyntheticReplay,
            canCancelCompositionSafely: canCancelCompositionSafely,
            canRestoreReliably: canRestoreReliably,
            canVerifyRecovery: canVerifyRecovery
        )
    }
}

public actor IMECompatibilityRegistry {
    private var evidenceByKey: [IMECompatibilityKey: IMECompatibilityEvidence] = [:]

    public init(seed: [IMECompatibilityEvidence] = []) {
        for item in seed {
            evidenceByKey[item.key] = item
        }
    }

    public func upsert(_ evidence: IMECompatibilityEvidence) {
        let existing = evidenceByKey[evidence.key]
        if let existing, rank(existing.level) > rank(evidence.level) {
            return
        }
        evidenceByKey[evidence.key] = evidence
    }

    public func evidence(for key: IMECompatibilityKey) -> IMECompatibilityEvidence? {
        evidenceByKey[key]
    }

    public func capabilities(for key: IMECompatibilityKey) -> IMECapabilities {
        evidenceByKey[key]?.capabilities.runtime ?? IMECapabilities()
    }

    public func allEvidence() -> [IMECompatibilityEvidence] {
        evidenceByKey.values.sorted {
            if $0.key.inputSourceID != $1.key.inputSourceID {
                return $0.key.inputSourceID < $1.key.inputSourceID
            }
            if $0.key.hostBundleIdentifier != $1.key.hostBundleIdentifier {
                return $0.key.hostBundleIdentifier < $1.key.hostBundleIdentifier
            }
            return $0.key.direction.rawValue < $1.key.direction.rawValue
        }
    }

    private func rank(_ level: CompatibilityEvidenceLevel) -> Int {
        switch level {
        case .prepared: return 0
        case .observed: return 1
        case .verified: return 2
        }
    }
}

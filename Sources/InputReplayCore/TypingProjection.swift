import Foundation
import CoreGraphics
import Carbon

public enum ProjectedCharacterKind: String, Sendable, Equatable {
    case text
    case whitespace
    case punctuation
    case strongBoundary
}

public struct ProjectedCharacter: Sendable, Equatable {
    public let value: Character
    public let kind: ProjectedCharacterKind

    public init(value: Character, kind: ProjectedCharacterKind) {
        self.value = value
        self.kind = kind
    }
}

public struct TextBoundaryPolicy: Sendable, Equatable {
    public var splitOnWhitespace: Bool
    public var splitOnPunctuation: Bool

    public init(splitOnWhitespace: Bool, splitOnPunctuation: Bool = true) {
        self.splitOnWhitespace = splitOnWhitespace
        self.splitOnPunctuation = splitOnPunctuation
    }

    /// Useful for Pinyin-like raw Latin sequences where spaces may be part of
    /// the user's intended IME interaction, while punctuation still separates
    /// clauses/segments.
    public static let pinyinLike = TextBoundaryPolicy(
        splitOnWhitespace: false,
        splitOnPunctuation: true
    )

    /// Useful for code-based IMEs whose space key commonly commits a unit.
    /// This is a policy input, not a claim that every Wubi implementation must
    /// behave identically.
    public static let codeIMEConservative = TextBoundaryPolicy(
        splitOnWhitespace: true,
        splitOnPunctuation: true
    )
}

public struct TypingProjection: Sendable, Equatable {
    public let characters: [ProjectedCharacter]
    /// False when the event stream contains operations whose resulting visible
    /// text cannot be reconstructed from key events alone (for example Cmd-V).
    public let isTextProjectionReliable: Bool
    public let hadBackspace: Bool

    public init(
        characters: [ProjectedCharacter],
        isTextProjectionReliable: Bool,
        hadBackspace: Bool
    ) {
        self.characters = characters
        self.isTextProjectionReliable = isTextProjectionReliable
        self.hadBackspace = hadBackspace
    }

    public var visibleTextEstimate: String {
        String(characters.map(\.value))
    }

    /// Returns only the suffix allowed by the selected IME boundary policy.
    /// A nil result means event-only reconstruction is unsafe and AX/host text
    /// must be treated as the source of truth instead.
    public func recoverableSuffix(using policy: TextBoundaryPolicy) -> String? {
        guard isTextProjectionReliable else { return nil }

        var start = characters.startIndex
        for index in characters.indices {
            let character = characters[index]
            switch character.kind {
            case .strongBoundary:
                start = characters.index(after: index)
            case .whitespace where policy.splitOnWhitespace:
                start = characters.index(after: index)
            case .punctuation where policy.splitOnPunctuation:
                start = characters.index(after: index)
            default:
                break
            }
        }

        guard start < characters.endIndex else { return "" }
        return String(characters[start...].map(\.value))
    }
}

public enum TypingProjector {
    public static func project(_ events: [CapturedKeyEvent]) -> TypingProjection {
        var output: [ProjectedCharacter] = []
        var reliable = true
        var hadBackspace = false

        for event in events where !event.isSynthetic {
            let keyCode = Int(event.keyCode)

            // Command/control shortcuts can paste, transform, navigate, invoke
            // candidate actions, etc. Their visible result cannot be inferred
            // safely from the key event's Unicode projection.
            if event.flags.contains(.maskCommand) || event.flags.contains(.maskControl) {
                reliable = false
                continue
            }

            if keyCode == kVK_Delete {
                hadBackspace = true
                if !output.isEmpty {
                    output.removeLast()
                }
                continue
            }

            if keyCode == kVK_ForwardDelete {
                // Forward delete depends on text *after* the caret, which this
                // recent-typing projection intentionally does not model.
                reliable = false
                continue
            }

            if keyCode == kVK_Return || keyCode == kVK_ANSI_KeypadEnter || keyCode == kVK_Tab {
                let value: Character = keyCode == kVK_Tab ? "\t" : "\n"
                output.append(ProjectedCharacter(value: value, kind: .strongBoundary))
                continue
            }

            guard let text = event.characters, !text.isEmpty else {
                // Modifier-only/function keys often have no text and can be
                // ignored. Escape is a composition/candidate boundary and must
                // invalidate event-only reconstruction.
                if keyCode == kVK_Escape {
                    reliable = false
                }
                continue
            }

            for character in text {
                output.append(
                    ProjectedCharacter(
                        value: character,
                        kind: classify(character)
                    )
                )
            }
        }

        return TypingProjection(
            characters: output,
            isTextProjectionReliable: reliable,
            hadBackspace: hadBackspace
        )
    }

    private static func classify(_ character: Character) -> ProjectedCharacterKind {
        if character == "\n" || character == "\r" || character == "\t" {
            return .strongBoundary
        }

        let scalars = character.unicodeScalars
        if scalars.allSatisfy({ CharacterSet.whitespaces.contains($0) }) {
            return .whitespace
        }
        if scalars.allSatisfy({
            CharacterSet.punctuationCharacters.contains($0) ||
            CharacterSet.symbols.contains($0)
        }) {
            return .punctuation
        }
        return .text
    }
}

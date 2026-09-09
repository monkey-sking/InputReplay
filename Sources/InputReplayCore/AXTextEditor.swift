import Foundation
import ApplicationServices

public enum AXTextEditorError: Error, Sendable, Equatable {
    case noFocusedElement
    case secureField
    case cannotReadSelection
    case cannotReadText
    case invalidRange
    case mutationFailed(Int32)
}

public struct AXTextSnapshot: Sendable, Equatable {
    public let text: String
    public let rangeLocation: Int
    public let rangeLength: Int

    public init(text: String, rangeLocation: Int, rangeLength: Int) {
        self.text = text
        self.rangeLocation = rangeLocation
        self.rangeLength = rangeLength
    }
}

public final class AXTextEditor: @unchecked Sendable {
    public init() {}

    public func snapshotCharactersBeforeCaret(count: Int) throws -> AXTextSnapshot {
        guard count > 0 else { throw AXTextEditorError.invalidRange }
        let element = try focusedElement()
        try assertNotSecure(element)

        let selection = try selectedRange(element)
        guard selection.length == 0, selection.location >= count else {
            throw AXTextEditorError.invalidRange
        }

        let target = CFRange(location: selection.location - count, length: count)
        let text = try stringForRange(target, element: element)
        return AXTextSnapshot(
            text: text,
            rangeLocation: target.location,
            rangeLength: target.length
        )
    }

    public func replace(snapshot: AXTextSnapshot, with replacement: String) throws {
        let element = try focusedElement()
        try assertNotSecure(element)
        let range = CFRange(location: snapshot.rangeLocation, length: snapshot.rangeLength)
        try replace(range: range, with: replacement, element: element)
    }

    public func replace(range: CFRange, with replacement: String) throws {
        let element = try focusedElement()
        try assertNotSecure(element)
        try replace(range: range, with: replacement, element: element)
    }

    private func replace(range: CFRange, with replacement: String, element: AXUIElement) throws {
        var mutableRange = range
        guard let rangeValue = AXValueCreate(.cfRange, &mutableRange) else {
            throw AXTextEditorError.invalidRange
        }

        let selectError = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            rangeValue
        )
        guard selectError == .success else {
            throw AXTextEditorError.mutationFailed(selectError.rawValue)
        }

        let replaceError = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            replacement as CFTypeRef
        )
        guard replaceError == .success else {
            throw AXTextEditorError.mutationFailed(replaceError.rawValue)
        }
    }

    private func focusedElement() throws -> AXUIElement {
        let system = AXUIElementCreateSystemWide()
        var raw: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            system,
            kAXFocusedUIElementAttribute as CFString,
            &raw
        )
        guard result == .success, let raw else {
            throw AXTextEditorError.noFocusedElement
        }
        return unsafeBitCast(raw, to: AXUIElement.self)
    }

    private func selectedRange(_ element: AXUIElement) throws -> CFRange {
        var raw: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &raw
        )
        guard result == .success, let raw else {
            throw AXTextEditorError.cannotReadSelection
        }

        let value = unsafeBitCast(raw, to: AXValue.self)
        guard AXValueGetType(value) == .cfRange else {
            throw AXTextEditorError.cannotReadSelection
        }

        var range = CFRange()
        guard AXValueGetValue(value, .cfRange, &range) else {
            throw AXTextEditorError.cannotReadSelection
        }
        return range
    }

    private func stringForRange(_ range: CFRange, element: AXUIElement) throws -> String {
        var mutableRange = range
        guard let rangeValue = AXValueCreate(.cfRange, &mutableRange) else {
            throw AXTextEditorError.invalidRange
        }

        var raw: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXStringForRangeParameterizedAttribute as CFString,
            rangeValue,
            &raw
        )
        guard result == .success, let text = raw as? String else {
            throw AXTextEditorError.cannotReadText
        }
        return text
    }

    private func assertNotSecure(_ element: AXUIElement) throws {
        var raw: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSubroleAttribute as CFString,
            &raw
        )
        if result == .success,
           let subrole = raw as? String,
           subrole.localizedCaseInsensitiveContains("secure") {
            throw AXTextEditorError.secureField
        }
    }
}

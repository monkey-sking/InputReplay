import Foundation
import ApplicationServices
import Carbon

public struct FocusedInputContextSnapshot: Sendable, Equatable {
    public let processID: pid_t
    public let focusIdentity: String?
    public let role: String?
    public let subrole: String?
    public let isSecure: Bool

    public init(
        processID: pid_t,
        focusIdentity: String?,
        role: String?,
        subrole: String?,
        isSecure: Bool
    ) {
        self.processID = processID
        self.focusIdentity = focusIdentity
        self.role = role
        self.subrole = subrole
        self.isSecure = isSecure
    }
}

public enum InputPrivacyGuard {
    /// macOS Secure Event Input is a hard privacy boundary. When enabled, the
    /// app must neither capture nor experimentally replay recent key events.
    public static var isSecureEventInputEnabled: Bool {
        IsSecureEventInputEnabled()
    }

    /// Reads only focused-element metadata needed to enforce privacy and focus
    /// boundaries. It never reads the focused field's value.
    public static func focusedContext() -> FocusedInputContextSnapshot? {
        let system = AXUIElementCreateSystemWide()
        var raw: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            system,
            kAXFocusedUIElementAttribute as CFString,
            &raw
        )
        guard result == .success, let raw else { return nil }

        let element = unsafeBitCast(raw, to: AXUIElement.self)
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)

        let role = stringAttribute(element, key: kAXRoleAttribute as CFString)
        let subrole = stringAttribute(element, key: kAXSubroleAttribute as CFString)
        let secureByAX = [role, subrole]
            .compactMap { $0?.lowercased() }
            .contains(where: { $0.contains("secure") || $0.contains("password") })

        // CFHash is used only as a short-lived identity token so moving to a
        // different focused AX element invalidates the previous typing burst.
        let identity = "\(pid):\(CFHash(element))"

        return FocusedInputContextSnapshot(
            processID: pid,
            focusIdentity: identity,
            role: role,
            subrole: subrole,
            isSecure: isSecureEventInputEnabled || secureByAX
        )
    }

    public static func mayCaptureCurrentFocus() -> Bool {
        guard !isSecureEventInputEnabled else { return false }
        guard let context = focusedContext() else {
            // If Accessibility cannot prove the focused field is safe yet,
            // event capture may still be used for the non-destructive probe;
            // destructive recovery remains separately gated by AX snapshots.
            return true
        }
        return !context.isSecure
    }

    public static func mayReplayIntoCurrentFocus() -> Bool {
        guard !isSecureEventInputEnabled else { return false }
        guard let context = focusedContext() else { return false }
        return !context.isSecure
    }

    private static func stringAttribute(_ element: AXUIElement, key: CFString) -> String? {
        var raw: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, key, &raw)
        guard result == .success, let raw else { return nil }
        return raw as? String
    }
}

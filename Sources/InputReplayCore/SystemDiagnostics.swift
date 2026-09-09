import Foundation
import ApplicationServices
import AppKit

public struct InputReplayDiagnostics: Sendable {
    public let macOSVersion: String
    public let accessibilityTrusted: Bool
    public let frontmostAppBundleIdentifier: String?
    public let frontmostAppName: String?
    public let currentInputSource: InputSourceDescriptor?
    public let availableInputSources: [InputSourceDescriptor]

    public init(
        macOSVersion: String,
        accessibilityTrusted: Bool,
        frontmostAppBundleIdentifier: String?,
        frontmostAppName: String?,
        currentInputSource: InputSourceDescriptor?,
        availableInputSources: [InputSourceDescriptor]
    ) {
        self.macOSVersion = macOSVersion
        self.accessibilityTrusted = accessibilityTrusted
        self.frontmostAppBundleIdentifier = frontmostAppBundleIdentifier
        self.frontmostAppName = frontmostAppName
        self.currentInputSource = currentInputSource
        self.availableInputSources = availableInputSources
    }
}

public enum SystemDiagnostics {
    public static func collect(
        inputSources: InputSourceController = InputSourceController()
    ) -> InputReplayDiagnostics {
        let processInfo = ProcessInfo.processInfo
        let frontmost = NSWorkspace.shared.frontmostApplication

        return InputReplayDiagnostics(
            macOSVersion: processInfo.operatingSystemVersionString,
            accessibilityTrusted: AXIsProcessTrusted(),
            frontmostAppBundleIdentifier: frontmost?.bundleIdentifier,
            frontmostAppName: frontmost?.localizedName,
            currentInputSource: inputSources.current(),
            availableInputSources: inputSources.availableKeyboardInputSources()
        )
    }
}

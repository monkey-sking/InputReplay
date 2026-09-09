import AppKit
import ApplicationServices

@MainActor
final class OnboardingWindowController: NSWindowController {
    private let preferences: AppPreferences
    private let onFinished: () -> Void
    private let permissionStatus = NSTextField(labelWithString: "")

    init(preferences: AppPreferences, onFinished: @escaping () -> Void) {
        self.preferences = preferences
        self.onFinished = onFinished

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 590, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = AppStrings.onboardingTitle
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        buildUI()
        refreshPermissionStatus()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        refreshPermissionStatus()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "keyboard.badge.ellipsis", accessibilityDescription: "InputReplay")
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 44, weight: .medium)
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 64).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 64).isActive = true

        let headline = NSTextField(labelWithString: AppStrings.onboardingHeadline)
        headline.font = .systemFont(ofSize: 25, weight: .semibold)

        let subtitle = NSTextField(wrappingLabelWithString: AppStrings.onboardingSubtitle)
        subtitle.textColor = .secondaryLabelColor

        let privacy = callout(
            symbol: "lock.shield",
            title: AppStrings.onboardingPrivacyTitle,
            body: AppStrings.onboardingPrivacyBody
        )
        let recovery = callout(
            symbol: "arrow.uturn.backward.circle",
            title: AppStrings.onboardingRecoveryTitle,
            body: AppStrings.onboardingRecoveryBody
        )
        let experimental = callout(
            symbol: "wrench.and.screwdriver",
            title: AppStrings.onboardingTestTitle,
            body: AppStrings.onboardingTestBody
        )

        permissionStatus.textColor = .secondaryLabelColor
        let permissionButton = NSButton(
            title: AppStrings.requestAccessibility,
            target: self,
            action: #selector(requestAccessibility)
        )
        permissionButton.bezelStyle = .rounded

        let permissionRow = NSStackView(views: [permissionStatus, permissionButton])
        permissionRow.orientation = .horizontal
        permissionRow.alignment = .centerY
        permissionRow.spacing = 12

        let finishButton = NSButton(
            title: AppStrings.onboardingFinish,
            target: self,
            action: #selector(finish)
        )
        finishButton.keyEquivalent = "\r"
        finishButton.bezelStyle = .rounded

        let footer = NSStackView(views: [NSView(), finishButton])
        footer.orientation = .horizontal
        footer.alignment = .centerY

        let headerText = NSStackView(views: [headline, subtitle])
        headerText.orientation = .vertical
        headerText.alignment = .leading
        headerText.spacing = 5

        let header = NSStackView(views: [icon, headerText])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 16

        let stack = NSStackView(views: [
            header,
            separator(),
            privacy,
            recovery,
            experimental,
            separator(),
            permissionRow,
            footer
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -24),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func callout(symbol: String, title: String, body: String) -> NSView {
        let image = NSImageView()
        image.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        image.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        image.translatesAutoresizingMaskIntoConstraints = false
        image.widthAnchor.constraint(equalToConstant: 28).isActive = true

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        let bodyLabel = NSTextField(wrappingLabelWithString: body)
        bodyLabel.textColor = .secondaryLabelColor

        let text = NSStackView(views: [titleLabel, bodyLabel])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 3

        let row = NSStackView(views: [image, text])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 12
        return row
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(greaterThanOrEqualToConstant: 530).isActive = true
        return box
    }

    private func refreshPermissionStatus() {
        permissionStatus.stringValue = AXIsProcessTrusted()
            ? AppStrings.accessibilityGranted
            : AppStrings.accessibilityRequired
    }

    @objc private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshPermissionStatus()
    }

    @objc private func finish() {
        preferences.hasCompletedOnboarding = true
        close()
        onFinished()
    }
}

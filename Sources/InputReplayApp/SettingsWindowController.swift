import AppKit
import ApplicationServices
import InputReplayCore

@MainActor
final class SettingsWindowController: NSWindowController {
    private let preferences: AppPreferences
    private let inputSources: InputSourceController
    private let launchAtLogin: LaunchAtLoginController
    private let onPreferencesChanged: () -> Void

    private let accessibilityStatus = NSTextField(labelWithString: "")
    private let showHUDCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let suggestionsCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let chinesePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let latinPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let loginStatus = NSTextField(labelWithString: "")

    init(
        preferences: AppPreferences,
        inputSources: InputSourceController,
        launchAtLogin: LaunchAtLoginController,
        onPreferencesChanged: @escaping () -> Void
    ) {
        self.preferences = preferences
        self.inputSources = inputSources
        self.launchAtLogin = launchAtLogin
        self.onPreferencesChanged = onPreferencesChanged

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 430),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = AppStrings.settingsTitle
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        buildUI()
        reload()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        reload()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func reload() {
        accessibilityStatus.stringValue = AXIsProcessTrusted()
            ? AppStrings.accessibilityGranted
            : AppStrings.accessibilityRequired

        showHUDCheckbox.state = preferences.showSwitchHUD ? .on : .off
        suggestionsCheckbox.state = preferences.suggestionsEnabled ? .on : .off

        switch launchAtLogin.state() {
        case .enabled:
            launchAtLoginCheckbox.state = .on
            loginStatus.stringValue = AppStrings.launchAtLoginEnabled
        case .disabled:
            launchAtLoginCheckbox.state = .off
            loginStatus.stringValue = AppStrings.launchAtLoginDisabled
        case .requiresApproval:
            launchAtLoginCheckbox.state = .on
            loginStatus.stringValue = AppStrings.launchAtLoginNeedsApproval
        case .unavailable(let message):
            launchAtLoginCheckbox.state = .off
            loginStatus.stringValue = AppStrings.choose("登录项不可用：\(message)", "Login item unavailable: \(message)")
        }

        reloadSourcePopups()
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let title = NSTextField(labelWithString: AppStrings.settingsHeadline)
        title.font = .systemFont(ofSize: 22, weight: .semibold)

        let subtitle = NSTextField(wrappingLabelWithString: AppStrings.settingsSubtitle)
        subtitle.textColor = .secondaryLabelColor

        showHUDCheckbox.title = AppStrings.showSwitchHUD
        showHUDCheckbox.target = self
        showHUDCheckbox.action = #selector(toggleHUD)

        suggestionsCheckbox.title = AppStrings.suggestionsEnabled
        suggestionsCheckbox.target = self
        suggestionsCheckbox.action = #selector(toggleSuggestions)

        launchAtLoginCheckbox.title = AppStrings.launchAtLogin
        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(toggleLaunchAtLogin)

        chinesePopup.target = self
        chinesePopup.action = #selector(chineseSourceChanged)
        latinPopup.target = self
        latinPopup.action = #selector(latinSourceChanged)

        let accessButton = NSButton(title: AppStrings.requestAccessibility, target: self, action: #selector(openAccessibilitySettings))
        accessButton.bezelStyle = .rounded

        let loginButton = NSButton(title: AppStrings.openLoginItemsSettings, target: self, action: #selector(openLoginItemsSettings))
        loginButton.bezelStyle = .rounded

        let resetWarningButton = NSButton(title: AppStrings.resetReplayWarning, target: self, action: #selector(resetReplayWarning))
        resetWarningButton.bezelStyle = .rounded

        let privacy = NSTextField(wrappingLabelWithString: AppStrings.settingsPrivacyNote)
        privacy.textColor = .secondaryLabelColor
        privacy.font = .systemFont(ofSize: 12)

        let stack = NSStackView(views: [
            title,
            subtitle,
            separator(),
            labeledRow(AppStrings.accessibilityLabel, accessibilityStatus, trailing: accessButton),
            showHUDCheckbox,
            suggestionsCheckbox,
            separator(),
            labeledPopupRow(AppStrings.chineseTargetLabel, popup: chinesePopup),
            labeledPopupRow(AppStrings.latinTargetLabel, popup: latinPopup),
            separator(),
            launchAtLoginCheckbox,
            labeledRow(AppStrings.loginItemStatusLabel, loginStatus, trailing: loginButton),
            separator(),
            resetWarningButton,
            privacy
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -22)
        ])
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(greaterThanOrEqualToConstant: 510).isActive = true
        return box
    }

    private func labeledPopupRow(_ label: String, popup: NSPopUpButton) -> NSView {
        let labelView = NSTextField(labelWithString: label)
        labelView.setContentHuggingPriority(.required, for: .horizontal)
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.widthAnchor.constraint(greaterThanOrEqualToConstant: 280).isActive = true

        let row = NSStackView(views: [labelView, popup])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    private func labeledRow(_ label: String, _ value: NSTextField, trailing: NSView) -> NSView {
        let labelView = NSTextField(labelWithString: label)
        labelView.setContentHuggingPriority(.required, for: .horizontal)
        value.textColor = .secondaryLabelColor

        let row = NSStackView(views: [labelView, value, trailing])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        return row
    }

    private func reloadSourcePopups() {
        let sources = inputSources.availableKeyboardInputSources()
        populate(
            chinesePopup,
            sources: sources,
            selectedID: preferences.preferredChineseInputSourceID
        )
        populate(
            latinPopup,
            sources: sources,
            selectedID: preferences.preferredLatinInputSourceID
        )
    }

    private func populate(
        _ popup: NSPopUpButton,
        sources: [InputSourceDescriptor],
        selectedID: String?
    ) {
        popup.removeAllItems()
        let none = NSMenuItem(title: AppStrings.autoOrUnset, action: nil, keyEquivalent: "")
        none.representedObject = nil
        popup.menu?.addItem(none)

        for source in sources {
            let title = source.localizedName ?? source.id
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.representedObject = source.id
            popup.menu?.addItem(item)
        }

        if let selectedID,
           let item = popup.itemArray.first(where: { ($0.representedObject as? String) == selectedID }) {
            popup.select(item)
        } else {
            popup.selectItem(at: 0)
        }
    }

    @objc private func toggleHUD() {
        preferences.showSwitchHUD = showHUDCheckbox.state == .on
        onPreferencesChanged()
    }

    @objc private func toggleSuggestions() {
        preferences.suggestionsEnabled = suggestionsCheckbox.state == .on
        onPreferencesChanged()
    }

    @objc private func toggleLaunchAtLogin() {
        let desired = launchAtLoginCheckbox.state == .on
        switch launchAtLogin.setEnabled(desired) {
        case .success:
            break
        case .failure(let error):
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = AppStrings.launchAtLoginFailed
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        reload()
    }

    @objc private func chineseSourceChanged() {
        preferences.preferredChineseInputSourceID = chinesePopup.selectedItem?.representedObject as? String
        onPreferencesChanged()
    }

    @objc private func latinSourceChanged() {
        preferences.preferredLatinInputSourceID = latinPopup.selectedItem?.representedObject as? String
        onPreferencesChanged()
    }

    @objc private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func openLoginItemsSettings() {
        launchAtLogin.openSystemSettings()
    }

    @objc private func resetReplayWarning() {
        preferences.resetDevelopmentWarnings()
        let alert = NSAlert()
        alert.messageText = AppStrings.replayWarningReset
        alert.runModal()
    }
}

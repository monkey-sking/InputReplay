import AppKit
import ApplicationServices
import InputReplayCore

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let inputSources = InputSourceController()
    private let ringBuffer = KeystrokeRingBuffer()
    private let contextTracker = InputContextTracker(
        configuration: .init(burstIdleGap: 1.25, switchDebounce: 0.12, suggestionTTL: 6.0)
    )
    private let replayEngine: ReplayEngine
    private let preferences = AppPreferences()
    private let hud = HUDPresenter()

    private lazy var runtime = InputReplayRuntime(
        inputSources: inputSources,
        ringBuffer: ringBuffer,
        contextTracker: contextTracker
    ) { [weak self] signal in
        Task { @MainActor [weak self] in
            self?.handleSwitchSignal(signal)
        }
    }

    private lazy var shortcutMonitor = GlobalShortcutMonitor { [weak self] in
        self?.replayPreviousBurst()
    }

    private var monitoringStarted = false
    private var lastSwitchSignal: InputSourceSwitchSignal?
    private var workspaceObservers: [NSObjectProtocol] = []

    private let monitoringItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let accessibilityItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let currentSourceItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let latestTargetItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let chineseTargetItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let latinTargetItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let showHUDItem = NSMenuItem(title: AppStrings.showSwitchHUD, action: #selector(toggleSwitchHUD), keyEquivalent: "")

    override init() {
        replayEngine = ReplayEngine(inputSources: inputSources)
        super.init()
    }

    func start() {
        configureStatusItem()
        configureMenu()
        shortcutMonitor.start()
        installLifecycleObservers()
        startMonitoring()
    }

    func stop() async {
        shortcutMonitor.stop()
        removeLifecycleObservers()
        hud.dismiss()
        await runtime.stop()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshStatusLines()
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "keyboard.badge.ellipsis",
                accessibilityDescription: AppStrings.appName
            )
            button.imagePosition = .imageOnly
            button.toolTip = "InputReplay"
        }
        statusItem.menu = menu
    }

    private func configureMenu() {
        menu.delegate = self
        menu.autoenablesItems = false

        let titleItem = NSMenuItem(title: "InputReplay  \(AppStrings.version)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        [monitoringItem, accessibilityItem, currentSourceItem, latestTargetItem, chineseTargetItem, latinTargetItem].forEach {
            $0.isEnabled = false
            menu.addItem($0)
        }

        menu.addItem(.separator())
        addMenuItem(title: AppStrings.requestAccessibility, action: #selector(openAccessibilitySettings))
        addMenuItem(title: AppStrings.restartMonitoring, action: #selector(restartMonitoring))
        menu.addItem(.separator())

        let replayItem = addMenuItem(title: AppStrings.replayLastBurst, action: #selector(replayPreviousBurst))
        replayItem.keyEquivalent = ""
        let shortcutHint = NSMenuItem(title: AppStrings.replayLastBurstShortcut, action: nil, keyEquivalent: "")
        shortcutHint.isEnabled = false
        menu.addItem(shortcutHint)

        addMenuItem(title: AppStrings.markChinese, action: #selector(markCurrentAsChineseTarget))
        addMenuItem(title: AppStrings.markLatin, action: #selector(markCurrentAsLatinTarget))

        showHUDItem.target = self
        showHUDItem.state = preferences.showSwitchHUD ? .on : .off
        menu.addItem(showHUDItem)

        addMenuItem(title: AppStrings.clearRecentBuffer, action: #selector(clearRecentBuffer))
        menu.addItem(.separator())

        addMenuItem(title: AppStrings.copyDiagnostics, action: #selector(copyDiagnostics))
        addMenuItem(title: AppStrings.openGitHub, action: #selector(openGitHub))
        menu.addItem(.separator())
        addMenuItem(title: AppStrings.quit, action: #selector(quit))

        refreshStatusLines()
    }

    @discardableResult
    private func addMenuItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = true
        menu.addItem(item)
        return item
    }

    private func startMonitoring() {
        Task { [weak self] in
            guard let self else { return }
            let started = await runtime.start()
            monitoringStarted = started
            refreshStatusLines()
            if !started {
                hud.show(title: AppStrings.monitoringFailed)
            }
        }
    }

    @objc private func restartMonitoring() {
        Task { [weak self] in
            guard let self else { return }
            await runtime.stop()
            monitoringStarted = false
            let started = await runtime.start()
            monitoringStarted = started
            refreshStatusLines()
            hud.show(title: started ? AppStrings.monitoringOn : AppStrings.monitoringFailed)
        }
    }

    private func handleSwitchSignal(_ signal: InputSourceSwitchSignal) {
        lastSwitchSignal = signal
        refreshStatusLines()

        guard preferences.showSwitchHUD else { return }
        let sourceName = displayName(for: signal.newInputSourceID)
        if signal.previousBurst?.events.isEmpty == false {
            hud.show(title: "\(AppStrings.switchedTitle) · \(sourceName)", detail: AppStrings.replayAvailable)
        } else {
            hud.show(title: "\(AppStrings.switchedTitle) · \(sourceName)")
        }
    }

    @objc private func replayPreviousBurst() {
        guard showExperimentalReplayWarningIfNeeded() else { return }

        Task { [weak self] in
            guard let self else { return }
            guard let signal = await runtime.pendingSwitchSuggestion(),
                  let burst = signal.previousBurst,
                  !burst.events.isEmpty
            else {
                hud.show(title: AppStrings.noReplayCandidate)
                return
            }

            do {
                try replayEngine.replay(
                    events: burst.events,
                    through: signal.newInputSourceID,
                    interKeyDelayMicroseconds: 2_500
                )
                hud.show(
                    title: AppStrings.replaySent,
                    detail: displayName(for: signal.newInputSourceID),
                    duration: 3.0
                )
            } catch {
                hud.show(title: AppStrings.replayFailed, detail: String(describing: error), duration: 3.0)
            }
        }
    }

    private func showExperimentalReplayWarningIfNeeded() -> Bool {
        guard !preferences.hasShownReplayWarning else { return true }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = AppStrings.experimentalWarningTitle
        alert.informativeText = AppStrings.experimentalWarningBody
        alert.addButton(withTitle: AppStrings.continueButton)
        alert.addButton(withTitle: AppStrings.cancelButton)

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return false }
        preferences.hasShownReplayWarning = true
        return true
    }

    @objc private func markCurrentAsChineseTarget() {
        guard let current = inputSources.current() else { return }
        preferences.preferredChineseInputSourceID = current.id
        refreshStatusLines()
        hud.show(title: AppStrings.sourcePinnedChinese, detail: current.localizedName ?? current.id)
    }

    @objc private func markCurrentAsLatinTarget() {
        guard let current = inputSources.current() else { return }
        preferences.preferredLatinInputSourceID = current.id
        refreshStatusLines()
        hud.show(title: AppStrings.sourcePinnedLatin, detail: current.localizedName ?? current.id)
    }

    @objc private func toggleSwitchHUD() {
        preferences.showSwitchHUD.toggle()
        showHUDItem.state = preferences.showSwitchHUD ? .on : .off
    }

    @objc private func clearRecentBuffer() {
        Task { [weak self] in
            guard let self else { return }
            await runtime.clearSensitiveRecentState()
            lastSwitchSignal = nil
            refreshStatusLines()
            hud.show(title: AppStrings.cacheCleared)
        }
    }

    @objc private func copyDiagnostics() {
        let report = SystemDiagnostics.collect(inputSources: inputSources)
        var lines: [String] = [
            "InputReplay \(AppStrings.version)",
            "macOS=\(report.macOSVersion)",
            "accessibilityTrusted=\(report.accessibilityTrusted)",
            "monitoringStarted=\(monitoringStarted)",
            "frontmostApp=\(report.frontmostAppBundleIdentifier ?? "unknown") [\(report.frontmostAppName ?? "")]",
            "currentInputSource=\(report.currentInputSource?.id ?? "unknown") [\(report.currentInputSource?.localizedName ?? "")]",
            "preferredChinese=\(preferences.preferredChineseInputSourceID ?? "unset")",
            "preferredLatin=\(preferences.preferredLatinInputSourceID ?? "unset")",
            "availableInputSources=\(report.availableInputSources.count)"
        ]
        for source in report.availableInputSources {
            lines.append("- \(source.id) [\(source.localizedName ?? "")] bundle=\(source.bundleIdentifier ?? "")")
        }

        let text = lines.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        hud.show(title: AppStrings.copiedDiagnostics)
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openGitHub() {
        guard let url = URL(string: "https://github.com/monkey-sking/InputReplay") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func refreshStatusLines() {
        monitoringItem.title = monitoringStarted ? AppStrings.monitoringOn : AppStrings.monitoringOff
        accessibilityItem.title = AXIsProcessTrusted() ? AppStrings.accessibilityGranted : AppStrings.accessibilityRequired

        let current = inputSources.current()
        currentSourceItem.title = "\(AppStrings.currentInputSource)：\(current?.localizedName ?? current?.id ?? AppStrings.noTarget)"

        let latestTarget = lastSwitchSignal.map { displayName(for: $0.newInputSourceID) } ?? AppStrings.noTarget
        latestTargetItem.title = "\(AppStrings.replayTarget)：\(latestTarget)"

        chineseTargetItem.title = "中文目标 / Chinese: \(displayName(for: preferences.preferredChineseInputSourceID))"
        latinTargetItem.title = "英文目标 / Latin: \(displayName(for: preferences.preferredLatinInputSourceID))"
        showHUDItem.state = preferences.showSwitchHUD ? .on : .off
    }

    private func displayName(for inputSourceID: String?) -> String {
        guard let inputSourceID, !inputSourceID.isEmpty else { return AppStrings.noTarget }
        if let source = inputSources.availableKeyboardInputSources().first(where: { $0.id == inputSourceID }) {
            return source.localizedName ?? source.id
        }
        return inputSourceID
    }

    private func installLifecycleObservers() {
        let center = NSWorkspace.shared.notificationCenter
        let sleep = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.invalidateForLifecycleBoundary()
            }
        }
        let wake = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.invalidateForLifecycleBoundary()
            }
        }
        workspaceObservers = [sleep, wake]
    }

    private func removeLifecycleObservers() {
        let center = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers {
            center.removeObserver(observer)
        }
        workspaceObservers.removeAll()
    }

    private func invalidateForLifecycleBoundary() async {
        await runtime.clearSensitiveRecentState()
        lastSwitchSignal = nil
        hud.dismiss()
        refreshStatusLines()
    }
}

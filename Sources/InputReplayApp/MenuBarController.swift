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
    private let launchAtLogin = LaunchAtLoginController()

    private lazy var recoveryCoordinator = RecoveryCoordinator(
        inputSources: inputSources,
        replayer: replayEngine,
        verifier: ConservativeRecoveryVerifier()
    )

    private lazy var runtime = InputReplayRuntime(
        inputSources: inputSources,
        ringBuffer: ringBuffer,
        contextTracker: contextTracker,
        physicalEventFilter: { event in
            ProductShortcutPolicy.shouldCapture(event)
        }
    ) { [weak self] signal in
        Task { @MainActor [weak self] in
            self?.handleSwitchSignal(signal)
        }
    }

    private lazy var shortcutMonitor = GlobalShortcutMonitor { [weak self] in
        self?.replayPreviousBurst()
    }

    private lazy var settingsController = SettingsWindowController(
        preferences: preferences,
        inputSources: inputSources,
        launchAtLogin: launchAtLogin
    ) { [weak self] in
        self?.refreshStatusLines()
    }

    private lazy var onboardingController = OnboardingWindowController(
        preferences: preferences
    ) { [weak self] in
        self?.settingsController.reload()
        self?.restartMonitoring()
    }

    private var monitoringStarted = false
    private var lastSwitchSignal: InputSourceSwitchSignal?
    private var workspaceObservers: [NSObjectProtocol] = []

    private let monitoringItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let accessibilityItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let privacyItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let currentSourceItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let latestTargetItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let latestBurstItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let chineseTargetItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let latinTargetItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let undoItem = NSMenuItem(title: AppStrings.undoLastRecovery, action: #selector(undoLastRecovery), keyEquivalent: "")
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

        if !preferences.hasCompletedOnboarding {
            DispatchQueue.main.async { [weak self] in
                self?.onboardingController.show()
            }
        }
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
        refreshStatusIcon()
        statusItem.menu = menu
    }

    private func configureMenu() {
        menu.delegate = self
        menu.autoenablesItems = false

        let titleItem = NSMenuItem(title: "InputReplay  \(AppStrings.version)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        [
            monitoringItem,
            accessibilityItem,
            privacyItem,
            currentSourceItem,
            latestTargetItem,
            latestBurstItem,
            chineseTargetItem,
            latinTargetItem
        ].forEach {
            $0.isEnabled = false
            menu.addItem($0)
        }

        menu.addItem(.separator())
        addMenuItem(title: AppStrings.requestAccessibility, action: #selector(openAccessibilitySettings))
        addMenuItem(title: AppStrings.restartMonitoring, action: #selector(restartMonitoring))
        menu.addItem(.separator())

        addMenuItem(title: AppStrings.replayLastBurst, action: #selector(replayPreviousBurst))
        let shortcutHint = NSMenuItem(title: AppStrings.replayLastBurstShortcut, action: nil, keyEquivalent: "")
        shortcutHint.isEnabled = false
        menu.addItem(shortcutHint)

        undoItem.target = self
        undoItem.isEnabled = false
        menu.addItem(undoItem)

        addMenuItem(title: AppStrings.markChinese, action: #selector(markCurrentAsChineseTarget))
        addMenuItem(title: AppStrings.markLatin, action: #selector(markCurrentAsLatinTarget))

        showHUDItem.target = self
        showHUDItem.state = preferences.showSwitchHUD ? .on : .off
        menu.addItem(showHUDItem)

        addMenuItem(title: AppStrings.clearRecentBuffer, action: #selector(clearRecentBuffer))
        menu.addItem(.separator())

        addMenuItem(title: AppStrings.settingsMenu, action: #selector(openSettings))
        addMenuItem(title: AppStrings.onboardingMenu, action: #selector(openOnboarding))
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
        if InputPrivacyGuard.isSecureEventInputEnabled {
            Task { [weak self] in
                guard let self else { return }
                await runtime.clearSensitiveRecentState()
                lastSwitchSignal = nil
                refreshStatusLines()
            }
            return
        }

        lastSwitchSignal = signal
        refreshStatusLines()

        guard preferences.showSwitchHUD else { return }
        let sourceName = displayName(for: signal.newInputSourceID)

        guard preferences.suggestionsEnabled,
              let burst = signal.previousBurst,
              !burst.events.isEmpty
        else {
            hud.show(title: "\(AppStrings.switchedTitle) · \(sourceName)")
            return
        }

        let preview = burstPreview(burst)
        let detail = preview.isEmpty ? AppStrings.replayAvailable : "\(preview)  ·  \(AppStrings.replayAvailable)"
        hud.show(title: "\(AppStrings.switchedTitle) · \(sourceName)", detail: detail, duration: 3.0)
    }

    @objc private func replayPreviousBurst() {
        guard InputPrivacyGuard.mayReplayIntoCurrentFocus() else {
            Task { [weak self] in
                guard let self else { return }
                await runtime.clearSensitiveRecentState()
                lastSwitchSignal = nil
                refreshStatusLines()
                hud.show(title: AppStrings.secureInputBlocked, duration: 3.0)
            }
            return
        }

        // First activation only presents a non-focus-stealing warning. The
        // second activation performs the probe so an NSAlert never steals the
        // editor focus that we are about to validate.
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
                let plan = try SmokeReplayPlanner.makePlan(
                    events: burst.events,
                    currentFocus: InputPrivacyGuard.focusedContext()
                )

                try replayEngine.replay(
                    events: plan.events,
                    through: signal.newInputSourceID,
                    sourceSettleDelayMicroseconds: 50_000,
                    interKeyDelayMicroseconds: 2_500
                )

                let preview = burstPreview(burst)
                let target = displayName(for: signal.newInputSourceID)

                // One-shot probe: do not leave a stale replay candidate around
                // after successful replay where another shortcut press could
                // append the same content again by accident.
                await runtime.clearSensitiveRecentState()
                lastSwitchSignal = nil
                refreshStatusLines()

                hud.show(
                    title: AppStrings.replaySent,
                    detail: preview.isEmpty ? target : "\(preview)  →  \(target)",
                    duration: 3.4
                )
            } catch let rejection as SmokeReplayRejection {
                let title: String
                if rejection == .focusChanged || rejection == .focusUnavailable {
                    title = AppStrings.focusChanged
                } else {
                    title = AppStrings.replayBlocked
                }
                hud.show(title: title, detail: rejection.description, duration: 4.0)
            } catch {
                hud.show(title: AppStrings.replayFailed, detail: String(describing: error), duration: 3.0)
            }
        }
    }

    private func showExperimentalReplayWarningIfNeeded() -> Bool {
        guard !preferences.hasShownReplayWarning else { return true }
        preferences.hasShownReplayWarning = true
        hud.show(
            title: AppStrings.experimentalWarningTitle,
            detail: AppStrings.choose(
                "第一次只显示提示，不执行 Replay。确认当前仍在测试文本框后，再按一次 ⌃⌥R。",
                "The first press only shows this warning. Keep focus in the test field, then press ⌃⌥R again."
            ),
            duration: 5.0
        )
        return false
    }

    @objc private func undoLastRecovery() {
        Task { [weak self] in
            guard let self else { return }
            do {
                guard try await recoveryCoordinator.restoreLast() != nil else {
                    hud.show(title: AppStrings.undoUnavailable)
                    return
                }
                hud.show(title: AppStrings.choose("已恢复到修正前内容", "Restored the pre-recovery content"))
            } catch {
                hud.show(
                    title: AppStrings.choose("撤销恢复失败", "Undo Recovery Failed"),
                    detail: String(describing: error),
                    duration: 3.5
                )
            }
            refreshUndoAvailability()
        }
    }

    @objc private func markCurrentAsChineseTarget() {
        guard let current = inputSources.current() else { return }
        preferences.preferredChineseInputSourceID = current.id
        settingsController.reload()
        refreshStatusLines()
        hud.show(title: AppStrings.sourcePinnedChinese, detail: current.localizedName ?? current.id)
    }

    @objc private func markCurrentAsLatinTarget() {
        guard let current = inputSources.current() else { return }
        preferences.preferredLatinInputSourceID = current.id
        settingsController.reload()
        refreshStatusLines()
        hud.show(title: AppStrings.sourcePinnedLatin, detail: current.localizedName ?? current.id)
    }

    @objc private func toggleSwitchHUD() {
        preferences.showSwitchHUD.toggle()
        showHUDItem.state = preferences.showSwitchHUD ? .on : .off
        settingsController.reload()
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

    @objc private func openSettings() {
        settingsController.show()
    }

    @objc private func openOnboarding() {
        onboardingController.show()
    }

    @objc private func copyDiagnostics() {
        let report = SystemDiagnostics.collect(inputSources: inputSources)
        var lines: [String] = [
            "InputReplay \(AppStrings.version)",
            "macOS=\(report.macOSVersion)",
            "accessibilityTrusted=\(report.accessibilityTrusted)",
            "secureEventInput=\(InputPrivacyGuard.isSecureEventInputEnabled)",
            "focusedContextSecure=\(InputPrivacyGuard.focusedContext()?.isSecure ?? false)",
            "monitoringStarted=\(monitoringStarted)",
            "typedContentIncluded=false",
            "frontmostApp=\(report.frontmostAppBundleIdentifier ?? "unknown") [\(report.frontmostAppName ?? "")]",
            "currentInputSource=\(report.currentInputSource?.id ?? "unknown") [\(report.currentInputSource?.localizedName ?? "")]",
            "preferredChinese=\(preferences.preferredChineseInputSourceID ?? "unset")",
            "preferredLatin=\(preferences.preferredLatinInputSourceID ?? "unset")",
            "suggestionsEnabled=\(preferences.suggestionsEnabled)",
            "showSwitchHUD=\(preferences.showSwitchHUD)",
            "availableInputSources=\(report.availableInputSources.count)"
        ]

        if let signal = lastSwitchSignal {
            lines.append("lastSwitch=\(signal.previousInputSourceID) -> \(signal.newInputSourceID)")
            if let burst = signal.previousBurst {
                let projection = TypingProjector.project(burst.events)
                lines.append("lastBurstEvents=\(burst.events.count)")
                lines.append("lastBurstProjectionReliable=\(projection.isTextProjectionReliable)")
                lines.append("lastBurstHadBackspace=\(projection.hadBackspace)")
                lines.append("lastBurstProjectedCharacterCount=\(projection.characters.count)")
            }
        }

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

        let secure = InputPrivacyGuard.isSecureEventInputEnabled || InputPrivacyGuard.focusedContext()?.isSecure == true
        privacyItem.title = AppStrings.choose(
            secure ? "安全输入：已保护（暂停捕获）" : "安全输入：普通",
            secure ? "Secure input: Protected (capture paused)" : "Secure input: Normal"
        )

        let current = inputSources.current()
        currentSourceItem.title = "\(AppStrings.currentInputSource)：\(current?.localizedName ?? current?.id ?? AppStrings.noTarget)"

        let latestTarget = lastSwitchSignal.map { displayName(for: $0.newInputSourceID) } ?? AppStrings.noTarget
        latestTargetItem.title = "\(AppStrings.replayTarget)：\(latestTarget)"

        if let burst = lastSwitchSignal?.previousBurst, !burst.events.isEmpty {
            let preview = burstPreview(burst)
            latestBurstItem.title = AppStrings.choose(
                "上一段：\(preview.isEmpty ? "（复杂输入）" : preview)",
                "Previous burst: \(preview.isEmpty ? "(complex input)" : preview)"
            )
        } else {
            latestBurstItem.title = AppStrings.choose("上一段：暂无", "Previous burst: None")
        }

        chineseTargetItem.title = "中文目标 / Chinese: \(displayName(for: preferences.preferredChineseInputSourceID))"
        latinTargetItem.title = "英文目标 / Latin: \(displayName(for: preferences.preferredLatinInputSourceID))"
        showHUDItem.state = preferences.showSwitchHUD ? .on : .off
        refreshStatusIcon(secure: secure)
        refreshUndoAvailability()
    }

    private func refreshUndoAvailability() {
        Task { [weak self] in
            guard let self else { return }
            let transaction = await recoveryCoordinator.lastRestorableTransaction
            undoItem.isEnabled = transaction != nil
        }
    }

    private func refreshStatusIcon(secure: Bool? = nil) {
        guard let button = statusItem.button else { return }
        let protected = secure ?? InputPrivacyGuard.isSecureEventInputEnabled
        let symbol = protected ? "lock.shield" : "keyboard.badge.ellipsis"
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: AppStrings.appName)
        button.imagePosition = .imageOnly
        button.toolTip = protected ? AppStrings.secureInputBlocked : "InputReplay"
    }

    private func burstPreview(_ burst: TypingBurst) -> String {
        let projection = TypingProjector.project(burst.events)
        guard projection.isTextProjectionReliable else { return "" }
        let text = projection.visibleTextEstimate
            .replacingOccurrences(of: "\n", with: "↵")
            .replacingOccurrences(of: "\t", with: "⇥")
        if text.count <= 42 { return text }
        let end = text.index(text.startIndex, offsetBy: 39)
        return String(text[..<end]) + "…"
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

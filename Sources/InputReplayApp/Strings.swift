import Foundation

enum AppStrings {
    static var isChinese: Bool {
        Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true
    }

    static func choose(_ zh: String, _ en: String) -> String {
        isChinese ? zh : en
    }

    static let appName = "InputReplay"
    static let version = "0.1.0-dev"

    static var monitoringOn: String { choose("监听：已开启", "Monitoring: On") }
    static var monitoringOff: String { choose("监听：未开启", "Monitoring: Off") }
    static var accessibilityGranted: String { choose("辅助功能：已授权", "Accessibility: Granted") }
    static var accessibilityRequired: String { choose("辅助功能：需要授权", "Accessibility: Required") }
    static var currentInputSource: String { choose("当前输入法", "Current input source") }
    static var replayTarget: String { choose("最近切换目标", "Latest switch target") }
    static var noTarget: String { choose("暂无", "None") }
    static var requestAccessibility: String { choose("打开辅助功能权限…", "Open Accessibility Settings…") }
    static var restartMonitoring: String { choose("重新启动监听", "Restart Monitoring") }
    static var replayLastBurst: String { choose("实验：安全重放上一段输入", "Experimental: Safely Replay Previous Burst") }
    static var replayLastBurstShortcut: String { choose("快捷键：Control + Option + R", "Shortcut: Control + Option + R") }
    static var clearRecentBuffer: String { choose("清空最近输入缓存", "Clear Recent Input Buffer") }
    static var showSwitchHUD: String { choose("输入法切换时显示 HUD", "Show HUD on Input Source Switch") }
    static var suggestionsEnabled: String { choose("输入法切换后生成恢复建议", "Create recovery suggestions after input-source changes") }
    static var markChinese: String { choose("将当前输入法设为中文目标", "Set Current Source as Chinese Target") }
    static var markLatin: String { choose("将当前输入法设为英文目标", "Set Current Source as Latin Target") }
    static var copyDiagnostics: String { choose("复制诊断信息", "Copy Diagnostics") }
    static var openGitHub: String { choose("打开 GitHub", "Open GitHub") }
    static var settingsMenu: String { choose("设置…", "Settings…") }
    static var onboardingMenu: String { choose("重新打开首次使用指南…", "Show Onboarding…") }
    static var undoLastRecovery: String { choose("撤销上一次恢复", "Undo Last Recovery") }
    static var undoUnavailable: String { choose("暂无可撤销的恢复", "No recovery is available to undo") }
    static var quit: String { choose("退出 InputReplay", "Quit InputReplay") }

    static var switchedTitle: String { choose("输入法已切换", "Input source changed") }
    static var replayAvailable: String { choose("上一段输入可安全实验重放 · ⌃⌥R", "Previous burst can be safely replay-tested · ⌃⌥R") }
    static var noReplayCandidate: String { choose("没有可重放的上一段输入", "No previous burst is available to replay") }
    static var replaySent: String { choose("已发送安全实验重放，原文未删除", "Safe experimental replay sent; original text was not deleted") }
    static var replayFailed: String { choose("实验重放失败", "Experimental replay failed") }
    static var replayBlocked: String { choose("这段输入不适合安全 Replay 测试", "This burst is not safe for the replay smoke test") }
    static var focusChanged: String { choose("输入位置已经变化，已取消 Replay", "Focus changed, so replay was cancelled") }
    static var secureInputBlocked: String { choose("安全输入环境：已停止捕获与 Replay", "Secure input detected: capture and replay are blocked") }
    static var monitoringFailed: String { choose("监听启动失败，请先授权辅助功能", "Monitoring failed. Grant Accessibility permission first") }
    static var cacheCleared: String { choose("最近输入缓存已清空", "Recent input buffer cleared") }
    static var copiedDiagnostics: String { choose("诊断信息已复制", "Diagnostics copied") }
    static var sourcePinnedChinese: String { choose("已设为中文目标", "Set as Chinese target") }
    static var sourcePinnedLatin: String { choose("已设为英文目标", "Set as Latin target") }

    static var experimentalWarningTitle: String { choose("实验性 Replay 测试", "Experimental Replay Test") }
    static var experimentalWarningBody: String {
        choose(
            "这个测试不会删除你已经输入的原文。它只会对经过 append-only 安全检查的上一段物理按键进行 Replay；Backspace、Delete、方向键、Return、Tab、Esc 和系统快捷键都会被拒绝。Replay 前还会再次确认当前仍是同一个输入框。请只在普通文本框里测试。",
            "This test does not delete text you already typed. It only replays a previous physical-key burst after an append-only safety check. Backspace, Delete, navigation keys, Return, Tab, Escape, and system shortcuts are rejected, and InputReplay re-checks that focus is still in the same field before replaying. Test only in ordinary text fields."
        )
    }
    static var continueButton: String { choose("继续测试", "Continue") }
    static var cancelButton: String { choose("取消", "Cancel") }

    static var settingsTitle: String { choose("InputReplay 设置", "InputReplay Settings") }
    static var settingsHeadline: String { choose("InputReplay", "InputReplay") }
    static var settingsSubtitle: String {
        choose(
            "优先保证恢复安全。无法验证 Restore 的输入法或 App 会自动降级为建议/实验模式。",
            "Recovery safety comes first. IME/app combinations without a verified restore path automatically degrade to suggestion or experimental mode."
        )
    }
    static var accessibilityLabel: String { choose("权限", "Permission") }
    static var chineseTargetLabel: String { choose("中文目标输入法", "Chinese target input source") }
    static var latinTargetLabel: String { choose("英文目标输入法", "Latin target input source") }
    static var autoOrUnset: String { choose("未指定 / 自动", "Unset / Automatic") }
    static var launchAtLogin: String { choose("登录时启动 InputReplay", "Launch InputReplay at Login") }
    static var launchAtLoginEnabled: String { choose("登录项：已启用", "Login item: Enabled") }
    static var launchAtLoginDisabled: String { choose("登录项：未启用", "Login item: Disabled") }
    static var launchAtLoginNeedsApproval: String { choose("登录项：等待系统设置批准", "Login item: Awaiting approval in System Settings") }
    static var launchAtLoginFailed: String { choose("无法修改登录项", "Could Not Change Login Item") }
    static var loginItemStatusLabel: String { choose("状态", "Status") }
    static var openLoginItemsSettings: String { choose("打开登录项设置…", "Open Login Items Settings…") }
    static var resetReplayWarning: String { choose("重新显示 Replay 安全提示", "Reset Replay Safety Warning") }
    static var replayWarningReset: String { choose("下次实验 Replay 时会再次显示安全提示。", "The safety warning will be shown again on the next experimental replay.") }
    static var settingsPrivacyNote: String {
        choose(
            "隐私：最近按键仅短暂保存在内存中；安全输入/密码字段不进入缓存；复制诊断默认不包含实际输入文本。",
            "Privacy: recent key events are kept only briefly in memory; secure/password fields are excluded; copied diagnostics do not include typed text by default."
        )
    }

    static var onboardingTitle: String { choose("欢迎使用 InputReplay", "Welcome to InputReplay") }
    static var onboardingHeadline: String { choose("输错输入法，也不用重打", "Never retype because of the wrong input mode") }
    static var onboardingSubtitle: String {
        choose(
            "InputReplay 会记录极短期的本地物理按键历史，在你切换输入法后帮助恢复刚才打错的那一段。",
            "InputReplay keeps a very short local history of physical key events so it can help recover a recent wrong-input-mode burst after you switch input sources."
        )
    }
    static var onboardingPrivacyTitle: String { choose("本地、短暂、可清空", "Local, short-lived, clearable") }
    static var onboardingPrivacyBody: String {
        choose(
            "按键历史只在内存中保留约 15 秒 / 128 个事件；不会上传；密码框和 Secure Event Input 会直接停止捕获。",
            "Key history stays in memory for roughly 15 seconds / 128 events, is never uploaded by the core app, and capture stops in password fields or Secure Event Input."
        )
    }
    static var onboardingRecoveryTitle: String { choose("恢复优先，自动化靠后", "Recovery first, automation later") }
    static var onboardingRecoveryBody: String {
        choose(
            "当前开发版先验证安全 Replay。没有可靠 Restore 计划时，InputReplay 不会自动删除或改写你的文本。",
            "The current development build validates safe replay first. InputReplay will not automatically delete or rewrite text unless a reliable restore plan is available."
        )
    }
    static var onboardingTestTitle: String { choose("第一轮测试：TextEdit + Apple 拼音", "First test: TextEdit + Apple Pinyin") }
    static var onboardingTestBody: String {
        choose(
            "用 ABC 输入 ceshiyixia，切到 Apple 拼音，再按 Control + Option + R。原文应保留，同时同一组安全物理按键被再次发送。",
            "Type ceshiyixia using ABC, switch to Apple Pinyin, then press Control + Option + R. The original text should remain while the same safe physical keys are sent again."
        )
    }
    static var onboardingFinish: String { choose("进入 InputReplay", "Start Using InputReplay") }
}

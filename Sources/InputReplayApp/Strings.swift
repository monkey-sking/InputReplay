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
    static var replayLastBurst: String { choose("实验：重放上一段输入", "Experimental: Replay Previous Burst") }
    static var replayLastBurstShortcut: String { choose("快捷键：Control + Option + R", "Shortcut: Control + Option + R") }
    static var clearRecentBuffer: String { choose("清空最近输入缓存", "Clear Recent Input Buffer") }
    static var showSwitchHUD: String { choose("输入法切换时显示 HUD", "Show HUD on Input Source Switch") }
    static var markChinese: String { choose("将当前输入法设为中文目标", "Set Current Source as Chinese Target") }
    static var markLatin: String { choose("将当前输入法设为英文目标", "Set Current Source as Latin Target") }
    static var copyDiagnostics: String { choose("复制诊断信息", "Copy Diagnostics") }
    static var openGitHub: String { choose("打开 GitHub", "Open GitHub") }
    static var quit: String { choose("退出 InputReplay", "Quit InputReplay") }

    static var switchedTitle: String { choose("输入法已切换", "Input source changed") }
    static var replayAvailable: String { choose("上一段输入可实验重放 · ⌃⌥R", "Previous burst can be replay-tested · ⌃⌥R") }
    static var noReplayCandidate: String { choose("没有可重放的上一段输入", "No previous burst is available to replay") }
    static var replaySent: String { choose("已发送实验重放，原文未删除", "Experimental replay sent; original text was not deleted") }
    static var replayFailed: String { choose("实验重放失败", "Experimental replay failed") }
    static var monitoringFailed: String { choose("监听启动失败，请先授权辅助功能", "Monitoring failed. Grant Accessibility permission first") }
    static var cacheCleared: String { choose("最近输入缓存已清空", "Recent input buffer cleared") }
    static var copiedDiagnostics: String { choose("诊断信息已复制", "Diagnostics copied") }
    static var sourcePinnedChinese: String { choose("已设为中文目标", "Set as Chinese target") }
    static var sourcePinnedLatin: String { choose("已设为英文目标", "Set as Latin target") }

    static var experimentalWarningTitle: String { choose("实验性 Replay 测试", "Experimental Replay Test") }
    static var experimentalWarningBody: String {
        choose(
            "这个测试不会删除你已经输入的原文。它只会把上一段物理按键通过你刚切换到的输入法再次发送，用来验证拼音、五笔或第三方输入法是否接受 synthetic replay。请只在普通文本框里测试，不要在密码框或敏感内容附近使用。",
            "This test does not delete the text you already typed. It only sends the previous physical key burst again through the input source you just switched to, so we can verify whether Pinyin, Wubi, or a third-party IME accepts synthetic replay. Test only in ordinary text fields, never around passwords or sensitive content."
        )
    }
    static var continueButton: String { choose("继续测试", "Continue") }
    static var cancelButton: String { choose("取消", "Cancel") }
}

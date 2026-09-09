import Foundation

final class AppPreferences {
    private enum Key {
        static let preferredChineseInputSourceID = "preferredChineseInputSourceID"
        static let preferredLatinInputSourceID = "preferredLatinInputSourceID"
        static let showSwitchHUD = "showSwitchHUD"
        static let suggestionsEnabled = "suggestionsEnabled"
        static let hasShownReplayWarning = "hasShownReplayWarning"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Key.showSwitchHUD) == nil {
            defaults.set(true, forKey: Key.showSwitchHUD)
        }
        if defaults.object(forKey: Key.suggestionsEnabled) == nil {
            defaults.set(true, forKey: Key.suggestionsEnabled)
        }
    }

    var preferredChineseInputSourceID: String? {
        get { defaults.string(forKey: Key.preferredChineseInputSourceID) }
        set { defaults.set(newValue, forKey: Key.preferredChineseInputSourceID) }
    }

    var preferredLatinInputSourceID: String? {
        get { defaults.string(forKey: Key.preferredLatinInputSourceID) }
        set { defaults.set(newValue, forKey: Key.preferredLatinInputSourceID) }
    }

    var showSwitchHUD: Bool {
        get { defaults.bool(forKey: Key.showSwitchHUD) }
        set { defaults.set(newValue, forKey: Key.showSwitchHUD) }
    }

    var suggestionsEnabled: Bool {
        get { defaults.bool(forKey: Key.suggestionsEnabled) }
        set { defaults.set(newValue, forKey: Key.suggestionsEnabled) }
    }

    var hasShownReplayWarning: Bool {
        get { defaults.bool(forKey: Key.hasShownReplayWarning) }
        set { defaults.set(newValue, forKey: Key.hasShownReplayWarning) }
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding) }
    }

    func resetDevelopmentWarnings() {
        hasShownReplayWarning = false
    }
}

import Foundation

final class AppPreferences {
    private enum Key {
        static let preferredChineseInputSourceID = "preferredChineseInputSourceID"
        static let preferredLatinInputSourceID = "preferredLatinInputSourceID"
        static let showSwitchHUD = "showSwitchHUD"
        static let hasShownReplayWarning = "hasShownReplayWarning"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Key.showSwitchHUD) == nil {
            defaults.set(true, forKey: Key.showSwitchHUD)
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

    var hasShownReplayWarning: Bool {
        get { defaults.bool(forKey: Key.hasShownReplayWarning) }
        set { defaults.set(newValue, forKey: Key.hasShownReplayWarning) }
    }
}

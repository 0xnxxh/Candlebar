import Foundation

final class PreferencesStore {
    private let key = "candlebar.preferences.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppPreferences {
        guard let data = defaults.data(forKey: key),
              let preferences = try? JSONDecoder().decode(AppPreferences.self, from: data) else {
            return .defaults
        }
        return preferences
    }

    func save(_ preferences: AppPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}

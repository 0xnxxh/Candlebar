import Foundation

final class PreferencesStore {
    private let key = "candlebar.preferences.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() throws -> AppPreferences {
        guard let data = defaults.data(forKey: key) else {
            return .defaults
        }
        return try JSONDecoder().decode(AppPreferences.self, from: data)
    }

    func save(_ preferences: AppPreferences) throws {
        let data = try JSONEncoder().encode(preferences)
        defaults.set(data, forKey: key)
    }
}

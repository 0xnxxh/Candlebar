import Foundation

final class AccountSnapshotStore {
    private let key = "candlebar.accountSnapshots.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AccountSnapshotHistory {
        guard let data = defaults.data(forKey: key),
              let history = try? JSONDecoder().decode(AccountSnapshotHistory.self, from: data) else {
            return .empty
        }
        return history
    }

    func save(_ history: AccountSnapshotHistory) {
        guard let data = try? JSONEncoder().encode(history) else {
            return
        }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

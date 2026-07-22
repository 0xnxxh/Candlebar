import Foundation

final class AccountSnapshotStore {
    private let key = "candlebar.accountSnapshots.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() throws -> AccountSnapshotHistory {
        guard let data = defaults.data(forKey: key) else {
            return .empty
        }
        return try JSONDecoder().decode(AccountSnapshotHistory.self, from: data)
    }

    func save(_ history: AccountSnapshotHistory) throws {
        let data = try JSONEncoder().encode(history)
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

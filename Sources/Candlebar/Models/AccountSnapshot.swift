import Foundation

struct AccountSnapshot: Codable, Equatable {
    var capturedAt: Date
    var usdEstimatedValue: Decimal
}

struct AccountSnapshotHistory: Codable, Equatable {
    var snapshots: [AccountSnapshot]

    static let empty = AccountSnapshotHistory(snapshots: [])

    mutating func record(_ snapshot: AccountSnapshot, now: Date = Date()) {
        snapshots.append(snapshot)
        let cutoff = now.addingTimeInterval(-49 * 60 * 60)
        snapshots = snapshots
            .filter { $0.capturedAt >= cutoff }
            .sorted { $0.capturedAt < $1.capturedAt }
    }

    func baseline24h(now: Date = Date()) -> AccountSnapshot? {
        let target = now.addingTimeInterval(-24 * 60 * 60)
        return snapshots
            .filter { $0.capturedAt <= target }
            .min { first, second in
                abs(first.capturedAt.timeIntervalSince(target))
                    < abs(second.capturedAt.timeIntervalSince(target))
            }
    }
}

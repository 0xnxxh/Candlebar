import CryptoKit
import Foundation

/// Stores only the current UTC day's complete wallet sample, scoped to an API key hash.
/// Binance's SPOT/MARGIN/FUTURES daily snapshots cannot reconstruct all-wallet history.
final class AccountBaselineStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "candlebar.walletBaseline.v1"
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func baseline(wallets: [AccountWallet], apiKey: String, now: Int64) throws -> AccountDailyBaseline? {
        try lock.withLock {
            let date = Date(timeIntervalSince1970: TimeInterval(now) / 1000)
            let dayStart = UTCTradingDay.start(of: date)
            let accountID = SHA256.hash(data: Data(apiKey.utf8)).map { String(format: "%02x", $0) }.joined()
            if let data = defaults.data(forKey: key) {
                let saved = try JSONDecoder().decode(AccountDailyBaseline.self, from: data)
                if saved.accountID == accountID, saved.dayStart == dayStart {
                    return saved
                }
            }
            // Any first successful sample can start observation tracking. Only samples
            // within the first UTC minute qualify as an approximate midnight baseline.
            let baseline = AccountDailyBaseline(
                accountID: accountID,
                dayStart: dayStart,
                sampledAt: date,
                wallets: wallets,
            )
            defaults.set(try JSONEncoder().encode(baseline), forKey: key)
            return baseline
        }
    }
}

struct AccountDailyBaseline: Codable {
    let accountID: String
    let dayStart: Date
    let sampledAt: Date
    let wallets: [AccountWallet]

    var basis: AccountChangeBasis {
        sampledAt.timeIntervalSince(dayStart) < 60 ? .utcMidnight : .observation
    }

    func change(current: [AccountWallet]) -> AccountDailyChange? {
        guard Set(current.map(\.name)).count == current.count,
              Set(current.map(\.name)) == Set(wallets.map(\.name)),
              Set(wallets.map(\.name)).count == wallets.count else { return nil }
        let original = Dictionary(uniqueKeysWithValues: wallets.map { ($0.name, $0.value) })
        let previousTotal = wallets.reduce(Decimal(0)) { $0 + $1.value }
        let amount = current.reduce(Decimal(0)) { $0 + $1.value } - previousTotal
        return AccountDailyChange(
            amount: amount,
            percent: previousTotal > 0 ? amount / previousTotal * 100 : nil,
            walletChanges: Dictionary(uniqueKeysWithValues: current.map { ($0.name, $0.value - original[$0.name]!) }),
        )
    }
}

struct AccountDailyChange {
    let amount: Decimal
    let percent: Decimal?
    let walletChanges: [String: Decimal]
}

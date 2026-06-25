import Foundation

enum FeedStatus: String, Codable {
    case idle
    case loading
    case live
    case warning
    case stale
    case offline
    case error
}

struct TickerSnapshot: Codable, Equatable {
    var symbol: String
    var market: MarketType
    var lastPrice: Decimal?
    var priceChangePercent: Decimal?
    var updatedAt: Date?
    var status: FeedStatus
    var message: String?
    var movement: PriceMovement = .flat

    static func loading(for item: WatchSymbol) -> TickerSnapshot {
        TickerSnapshot(
            symbol: item.symbol,
            market: item.market,
            lastPrice: nil,
            priceChangePercent: nil,
            updatedAt: nil,
            status: .loading,
            message: nil,
            movement: .flat,
        )
    }

    var isPositive: Bool {
        (priceChangePercent ?? 0) >= 0
    }

    func applyingFreshness(now: Date = Date()) -> TickerSnapshot {
        guard let updatedAt else {
            return self
        }
        var copy = self
        let age = now.timeIntervalSince(updatedAt)
        if age >= 30 {
            copy.status = .stale
            copy.message = "STALE \(Int(age))S"
        } else if age >= 10 {
            copy.status = .warning
            copy.message = "SLOW \(Int(age))S"
        } else if copy.status == .warning || copy.status == .stale {
            copy.status = .live
            copy.message = nil
        }
        return copy
    }
}

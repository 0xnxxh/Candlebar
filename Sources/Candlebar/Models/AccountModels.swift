import Foundation

struct APIKeyState: Equatable {
    var hasKey: Bool
    var statusText: String

    static let missing = APIKeyState(
        hasKey: false,
        statusText: "READ-ONLY KEY NEEDED",
    )
}

struct AccountOverview: Equatable {
    var status: FeedStatus
    var statusText: String
    var usdEstimatedValue: Decimal?
    var usdEstimatedChangeToday: Decimal?
    var usdEstimatedChangePercentToday: Decimal?
    var spotEstimatedValue: Decimal?
    var usdMWalletBalance: Decimal?
    var usdMUnrealizedPnL: Decimal?
    var coinMWalletBalance: Decimal?
    var coinMUnrealizedPnL: Decimal?
    var positions: [FuturesPosition]
    var updatedAt: Date?
    var message: String?

    static let notConfigured = AccountOverview(
        status: .idle,
        statusText: "READ-ONLY KEY NEEDED",
        usdEstimatedValue: nil,
        usdEstimatedChangeToday: nil,
        usdEstimatedChangePercentToday: nil,
        spotEstimatedValue: nil,
        usdMWalletBalance: nil,
        usdMUnrealizedPnL: nil,
        coinMWalletBalance: nil,
        coinMUnrealizedPnL: nil,
        positions: [],
        updatedAt: nil,
        message: nil,
    )
}

struct FuturesPosition: Identifiable, Equatable {
    var id: String { "\(market.rawValue):\(symbol):\(side)" }
    var market: MarketType
    var symbol: String
    var side: String
    var quantity: Decimal
    var entryPrice: Decimal?
    var markPrice: Decimal?
    var breakevenPrice: Decimal?
    var unrealizedPnL: Decimal?
    var liquidationPrice: Decimal?
    var leverage: String?

    var pnlRatio: Decimal? {
        guard let unrealizedPnL, let entryPrice, entryPrice != 0, quantity != 0 else {
            return nil
        }
        let notional = entryPrice * quantity.magnitude
        guard notional != 0 else {
            return nil
        }
        return (unrealizedPnL / notional) * 100
    }

    var displayLeverage: String {
        guard let leverage, !leverage.isEmpty else {
            return "--"
        }
        return leverage.hasSuffix("x") ? leverage : "\(leverage)x"
    }

    var isLong: Bool {
        quantity >= 0
    }
}

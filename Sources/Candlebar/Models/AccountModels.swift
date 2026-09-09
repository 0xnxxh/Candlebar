import Foundation

struct APIKeyState: Equatable {
    var hasKey: Bool
    var statusText: String

    static let missing = APIKeyState(
        hasKey: false,
        statusText: "READ-ONLY KEY NEEDED",
    )

    static let error = APIKeyState(
        hasKey: false,
        statusText: "KEYCHAIN ERROR",
    )
}

struct AccountOverview: Equatable {
    var status: FeedStatus
    var statusText: String
    var usdEstimatedValue: Decimal?
    var usdtChange: Decimal?
    var usdtChangePercent: Decimal?
    var wallets: [AccountWallet] = []
    var changeBaselineAt: Date? = nil
    var changeBasis: AccountChangeBasis? = nil
    var positions: [FuturesPosition]
    var updatedAt: Date?
    var message: String?

    static let notConfigured = AccountOverview(
        status: .idle,
        statusText: "READ-ONLY KEY NEEDED",
        usdEstimatedValue: nil,
        usdtChange: nil,
        usdtChangePercent: nil,
        positions: [],
        updatedAt: nil,
        message: nil,
    )

    static func keychainError(_ message: String) -> AccountOverview {
        AccountOverview(
            status: .error,
            statusText: "ACCOUNT CHECK FAILED",
            usdEstimatedValue: nil,
            usdtChange: nil,
            usdtChangePercent: nil,
            positions: [],
            updatedAt: Date(),
            message: message,
        )
    }
}

enum AccountChangeBasis {
    case utcMidnight
    case observation
}

struct AccountWallet: Identifiable, Equatable, Codable {
    var id: String { name }
    var name: String
    var value: Decimal
    var change: Decimal? = nil
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
    var realizedPnL: Decimal?
    var fundingFee: Decimal?
    var notional: Decimal?
    var positionInitialMargin: Decimal?
    var liquidationPrice: Decimal?
    var leverage: String?

    var pnlRatio: Decimal? {
        guard let unrealizedPnL,
              let positionInitialMargin,
              positionInitialMargin != 0 else {
            return nil
        }
        return (unrealizedPnL / positionInitialMargin.magnitude) * 100
    }

    var displayNotional: Decimal? {
        notional?.magnitude
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

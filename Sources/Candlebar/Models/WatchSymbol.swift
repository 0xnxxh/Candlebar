import Foundation

struct WatchSymbol: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var symbol: String
    var market: MarketType

    init(id: UUID = UUID(), symbol: String, market: MarketType) {
        self.id = id
        self.symbol = symbol.normalizedSymbol
        self.market = market
    }

    var cacheKey: String {
        "\(market.rawValue):\(symbol)"
    }
}

extension String {
    var normalizedSymbol: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "-", with: "")
            .uppercased()
    }
}

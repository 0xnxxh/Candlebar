import Foundation

struct ExchangeSymbol: Identifiable, Equatable {
    var symbol: String
    var market: MarketType
    var baseAsset: String
    var quoteAsset: String
    var status: String

    var id: String {
        "\(market.rawValue):\(symbol)"
    }

    var pairText: String {
        "\(baseAsset)/\(quoteAsset)"
    }

    func matches(_ query: String) -> Bool {
        let normalized = query.normalizedSymbol
        guard !normalized.isEmpty else {
            return true
        }
        return symbol.contains(normalized)
            || baseAsset.contains(normalized)
            || quoteAsset.contains(normalized)
            || pairText.normalizedSymbol.contains(normalized)
    }
}

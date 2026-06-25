import Foundation

struct DiagnosticsReport {
    var generatedAt: Date
    var preferences: AppPreferences
    var tickers: [String: TickerSnapshot]
    var accountOverview: AccountOverview
    var apiKeyState: APIKeyState
    var lastError: String?

    var redactedText: String {
        [
            "Candlebar Diagnostics",
            "Generated: \(ISO8601DateFormatter().string(from: generatedAt))",
            "API Key: \(apiKeyState.statusText)",
            "Account: \(accountOverview.statusText)",
            "USD Estimate: \(accountOverview.usdEstimatedValue.map(String.init(describing:)) ?? "N/A")",
            "UTC Day USD Change: \(accountOverview.usdEstimatedChangeToday.map(String.init(describing:)) ?? "N/A")",
            "Account Message: \(accountOverview.message ?? "NONE")",
            "Last Error: \(lastError ?? "NONE")",
            "Default Symbol ID: \(preferences.defaultSymbolID?.uuidString ?? "NONE")",
            "Compact Menu Bar: \(preferences.compactMenuBar)",
            "Hide Balances: \(preferences.hideBalances)",
            "Pixel Theme: \(preferences.pixelTheme)",
            "Price Decimals: \(preferences.priceDecimalPlaces)",
            "",
            "Watchlist:",
            watchlistText,
            "",
            "Tickers:",
            tickerText,
        ].joined(separator: "\n")
    }

    private var watchlistText: String {
        guard !preferences.watchlist.isEmpty else {
            return "- NONE"
        }
        return preferences.watchlist
            .map { "- \($0.market.shortName) \($0.symbol)" }
            .joined(separator: "\n")
    }

    private var tickerText: String {
        guard !tickers.isEmpty else {
            return "- NONE"
        }
        return tickers.values
            .sorted { $0.symbol < $1.symbol }
            .map { ticker in
                let updatedAt = ticker.updatedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "NEVER"
                return "- \(ticker.market.shortName) \(ticker.symbol) \(ticker.status.rawValue.uppercased()) updated=\(updatedAt) message=\(ticker.message ?? "NONE")"
            }
            .joined(separator: "\n")
    }
}

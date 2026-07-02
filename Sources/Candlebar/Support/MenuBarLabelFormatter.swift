import Foundation

enum MenuBarLabelFormatter {
    static func text(
        item: WatchSymbol,
        ticker: TickerSnapshot?,
        percentChange: Decimal?,
        compact: Bool,
        decimalPlaces: Int,
    ) -> String {
        let symbol = item.symbol.replacingOccurrences(of: "USDT", with: "")
        let price = compact
            ? CandleFormat.compactPrice(ticker?.lastPrice)
            : CandleFormat.price(ticker?.lastPrice, decimalPlaces: decimalPlaces)

        guard ticker?.lastPrice != nil else {
            return "\(symbol) --"
        }
        if let status = ticker?.status, status == .stale || status == .offline || status == .error {
            return "\(symbol) \(price) \(status.rawValue.uppercased())"
        }
        if compact {
            return "\(symbol) \(price)"
        }
        return "\(symbol) \(price) \(CandleFormat.percent(percentChange))"
    }
}

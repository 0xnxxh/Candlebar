import Foundation

enum CandleFormat {
    static func price(_ value: Decimal?, decimalPlaces: Int? = nil) -> String {
        guard let value else { return "--" }
        let number = value as NSDecimalNumber
        let absolute = number.decimalValue.magnitude
        let fixedPlaces = decimalPlaces.map { min(8, max(0, $0)) }
        let formatter = PriceFormatterCache.shared.formatter(
            minimumFractionDigits: fixedPlaces ?? 0,
            maximumFractionDigits: fixedPlaces ?? (absolute >= 100 ? 2 : 6),
        )
        return formatter.string(from: number) ?? "\(value)"
    }

    static func compactPrice(_ value: Decimal?) -> String {
        guard let value else { return "--" }
        let doubleValue = NSDecimalNumber(decimal: value).doubleValue
        let absolute = abs(doubleValue)
        if absolute >= 1_000_000 {
            return String(format: "%.2fM", doubleValue / 1_000_000)
        }
        if absolute >= 1_000 {
            return String(format: "%.2fK", doubleValue / 1_000)
        }
        if absolute >= 1 {
            return String(format: "%.2f", doubleValue)
        }
        return String(format: "%.6f", doubleValue)
    }

    static func percent(_ value: Decimal?) -> String {
        guard let value else { return "--" }
        let doubleValue = NSDecimalNumber(decimal: value).doubleValue
        return String(format: "%+.2f%%", doubleValue)
    }

    static func signedMoney(_ value: Decimal?) -> String {
        guard let value else { return "--" }
        let doubleValue = NSDecimalNumber(decimal: value).doubleValue
        return String(format: "%+.2f", doubleValue)
    }

    static func relativeTime(_ date: Date?) -> String {
        guard let date else { return "NEVER" }
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 5 { return "LIVE" }
        if seconds < 60 { return "\(seconds)S AGO" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)M AGO" }
        return "\(minutes / 60)H AGO"
    }
}

extension Decimal {
    var magnitude: Decimal {
        self < 0 ? -self : self
    }
}

/// `NumberFormatter` construction is expensive and price formatting runs for every
/// visible row on each redraw, so formatters are reused per digit configuration.
private final class PriceFormatterCache: @unchecked Sendable {
    static let shared = PriceFormatterCache()

    private let lock = NSLock()
    private var formatters: [Int: NumberFormatter] = [:]

    func formatter(minimumFractionDigits: Int, maximumFractionDigits: Int) -> NumberFormatter {
        let key = minimumFractionDigits * 100 + maximumFractionDigits
        lock.lock()
        defer { lock.unlock() }
        if let cached = formatters[key] {
            return cached
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        formatters[key] = formatter
        return formatter
    }
}

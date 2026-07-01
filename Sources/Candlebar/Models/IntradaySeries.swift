import Foundation

struct IntradayCandle: Codable, Equatable, Identifiable {
    var openTime: Date
    var open: Decimal
    var high: Decimal
    var low: Decimal
    var close: Decimal

    var id: Date { openTime }
}

struct IntradaySeries: Codable, Equatable {
    var symbol: String
    var market: MarketType
    var interval: IntradayInterval
    var dayStart: Date
    var candles: [IntradayCandle]
    var updatedAt: Date?
    var status: FeedStatus
    var message: String?

    init(
        symbol: String,
        market: MarketType,
        interval: IntradayInterval = .fifteenMinutes,
        dayStart: Date,
        candles: [IntradayCandle],
        updatedAt: Date?,
        status: FeedStatus,
        message: String?,
    ) {
        self.symbol = symbol
        self.market = market
        self.interval = interval
        self.dayStart = dayStart
        self.candles = candles
        self.updatedAt = updatedAt
        self.status = status
        self.message = message
    }

    static func loading(
        for item: WatchSymbol,
        interval: IntradayInterval,
        dayStart: Date = UTCTradingDay.start(of: Date()),
    ) -> IntradaySeries {
        IntradaySeries(
            symbol: item.symbol,
            market: item.market,
            interval: interval,
            dayStart: dayStart,
            candles: [],
            updatedAt: nil,
            status: .loading,
            message: nil,
        )
    }

    var baselineOpen: Decimal? {
        candles.first?.open
    }

    var latestClose: Decimal? {
        candles.last?.close
    }

    func percentChange(currentPrice: Decimal?) -> Decimal? {
        guard let baselineOpen, baselineOpen != 0 else {
            return nil
        }
        let current = currentPrice ?? latestClose
        guard let current else {
            return nil
        }
        return ((current - baselineOpen) / baselineOpen) * 100
    }
}

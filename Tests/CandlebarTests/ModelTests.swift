import Foundation
import XCTest
@testable import Candlebar

final class ModelTests: XCTestCase {
    func testWatchSymbolNormalization() {
        XCTAssertEqual(" btc/usdt ".normalizedSymbol, "BTCUSDT")
        XCTAssertEqual("eth-usdt".normalizedSymbol, "ETHUSDT")
    }

    func testPriceMovementComparesPreviousAndCurrentPrice() {
        XCTAssertEqual(PriceMovement(previous: 1, current: 2), .up)
        XCTAssertEqual(PriceMovement(previous: 2, current: 1), .down)
        XCTAssertEqual(PriceMovement(previous: 2, current: 2), .flat)
        XCTAssertEqual(PriceMovement(previous: nil, current: 2), .flat)
    }

    func testPriceFormatterUsesConfiguredDecimalPlaces() {
        XCTAssertEqual(CandleFormat.price(Decimal(string: "123.4567"), decimalPlaces: 3), "123.457")
        XCTAssertEqual(CandleFormat.price(Decimal(string: "123.4567"), decimalPlaces: 0), "123")
    }

    func testAppPreferencesDecodeOldPayloadDefaultsNewDisplayPreferences() throws {
        let json = """
        {
          "watchlist": [
            {
              "id": "00000000-0000-0000-0000-000000000001",
              "symbol": "BTCUSDT",
              "market": "spot"
            }
          ],
          "defaultSymbolID": null,
          "compactMenuBar": false,
          "hideBalances": false,
          "pixelTheme": true,
          "priceDecimalPlaces": 2
        }
        """
        let preferences = try JSONDecoder().decode(AppPreferences.self, from: Data(json.utf8))

        XCTAssertEqual(preferences.watchlist.first?.symbol, "BTCUSDT")
        XCTAssertFalse(preferences.hideLowValueAccounts)
        XCTAssertEqual(preferences.language, .english)
    }

    func testMenuBarLabelIncludesPriceOrExplicitMissingValue() {
        let item = WatchSymbol(symbol: "BTCUSDT", market: .spot)
        let ticker = TickerSnapshot(
            symbol: "BTCUSDT",
            market: .spot,
            lastPrice: Decimal(string: "123.45"),
            priceChangePercent: Decimal(string: "1.2"),
            updatedAt: Date(timeIntervalSince1970: 100),
            status: .live,
            message: nil,
        )

        XCTAssertEqual(
            MenuBarLabelFormatter.text(item: item, ticker: nil, compact: false, decimalPlaces: 2),
            "BTC --",
        )
        XCTAssertEqual(
            MenuBarLabelFormatter.text(item: item, ticker: ticker, compact: false, decimalPlaces: 2),
            "BTC 123.45 +1.20%",
        )
    }

    func testTickerFreshness() {
        let ticker = TickerSnapshot(
            symbol: "BTCUSDT",
            market: .spot,
            lastPrice: 100,
            priceChangePercent: 1,
            updatedAt: Date(timeIntervalSince1970: 100),
            status: .live,
            message: nil,
        )

        let slow = ticker.applyingFreshness(now: Date(timeIntervalSince1970: 115))
        XCTAssertEqual(slow.status, .warning)
        XCTAssertEqual(slow.message, "SLOW 15S")

        let stale = ticker.applyingFreshness(now: Date(timeIntervalSince1970: 135))
        XCTAssertEqual(stale.status, .stale)
        XCTAssertEqual(stale.message, "STALE 35S")
    }

    func testUTCTradingDayUsesUTCStart() {
        let date = Date(timeIntervalSince1970: 1_788_012_345)
        let start = UTCTradingDay.start(of: date)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents([.hour, .minute, .second], from: start)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
    }

    func testIntradaySeriesPercentUsesBaselineOpenAndCurrentPrice() {
        let series = IntradaySeries(
            symbol: "BTCUSDT",
            market: .spot,
            dayStart: Date(timeIntervalSince1970: 100),
            candles: [
                IntradayCandle(
                    openTime: Date(timeIntervalSince1970: 100),
                    open: 100,
                    high: 102,
                    low: 99,
                    close: 101,
                ),
            ],
            updatedAt: Date(timeIntervalSince1970: 110),
            status: .live,
            message: nil,
        )

        XCTAssertEqual(series.percentChange(currentPrice: 105), 5)
        XCTAssertEqual(series.percentChange(currentPrice: nil), 1)
    }

    func testBinanceKlinePayloadDecodesArrayShape() throws {
        let json = """
        [
          [
            1788019200000,
            "100.0",
            "110.0",
            "95.0",
            "105.0",
            "999",
            1788020099999
          ]
        ]
        """
        let payloads = try JSONDecoder().decode([BinanceKlinePayload].self, from: Data(json.utf8))

        XCTAssertEqual(payloads.first?.openTime, 1_788_019_200_000)
        XCTAssertEqual(payloads.first?.open, "100.0")
        XCTAssertEqual(payloads.first?.high, "110.0")
        XCTAssertEqual(payloads.first?.low, "95.0")
        XCTAssertEqual(payloads.first?.close, "105.0")
    }

    func testPositionPnLRatioUsesInitialMarginROI() {
        let long = FuturesPosition(
            market: .usdMFutures,
            symbol: "BTCUSDT",
            side: "LONG",
            quantity: 2,
            entryPrice: 100,
            markPrice: 110,
            breakevenPrice: nil,
            unrealizedPnL: 10,
            realizedPnL: nil,
            fundingFee: nil,
            notional: 200,
            positionInitialMargin: 40,
            liquidationPrice: nil,
            leverage: "5",
        )
        let short = FuturesPosition(
            market: .usdMFutures,
            symbol: "BTCUSDT",
            side: "SHORT",
            quantity: -2,
            entryPrice: 100,
            markPrice: 90,
            breakevenPrice: nil,
            unrealizedPnL: 10,
            realizedPnL: nil,
            fundingFee: nil,
            notional: -200,
            positionInitialMargin: 40,
            liquidationPrice: nil,
            leverage: "5",
        )

        XCTAssertEqual(long.pnlRatio, 25)
        XCTAssertEqual(short.pnlRatio, 25)
        XCTAssertEqual(short.displayNotional, 200)
    }

    func testPositionDisplayLeverageAddsSuffix() {
        let position = FuturesPosition(
            market: .usdMFutures,
            symbol: "BTCUSDT",
            side: "LONG",
            quantity: 1,
            entryPrice: 100,
            markPrice: 110,
            breakevenPrice: nil,
            unrealizedPnL: 10,
            realizedPnL: nil,
            fundingFee: nil,
            notional: nil,
            positionInitialMargin: nil,
            liquidationPrice: nil,
            leverage: "5",
        )

        XCTAssertEqual(position.displayLeverage, "5x")
    }

    func testPositionDirectionUsesQuantity() {
        let long = FuturesPosition(
            market: .usdMFutures,
            symbol: "BTCUSDT",
            side: "BOTH",
            quantity: 1,
            entryPrice: nil,
            markPrice: nil,
            breakevenPrice: nil,
            unrealizedPnL: nil,
            realizedPnL: nil,
            fundingFee: nil,
            notional: nil,
            positionInitialMargin: nil,
            liquidationPrice: nil,
            leverage: nil,
        )
        let short = FuturesPosition(
            market: .usdMFutures,
            symbol: "BTCUSDT",
            side: "BOTH",
            quantity: -1,
            entryPrice: nil,
            markPrice: nil,
            breakevenPrice: nil,
            unrealizedPnL: nil,
            realizedPnL: nil,
            fundingFee: nil,
            notional: nil,
            positionInitialMargin: nil,
            liquidationPrice: nil,
            leverage: nil,
        )

        XCTAssertTrue(long.isLong)
        XCTAssertFalse(short.isLong)
    }

    func testPositionCarriesRealizedPnLAndLocalizedLabel() {
        let position = FuturesPosition(
            market: .usdMFutures,
            symbol: "BTCUSDT",
            side: "LONG",
            quantity: 1,
            entryPrice: nil,
            markPrice: nil,
            breakevenPrice: nil,
            unrealizedPnL: nil,
            realizedPnL: 12.5,
            fundingFee: -1.25,
            notional: nil,
            positionInitialMargin: nil,
            liquidationPrice: nil,
            leverage: nil,
        )

        XCTAssertEqual(position.realizedPnL, 12.5)
        XCTAssertEqual(position.fundingFee, -1.25)
        XCTAssertEqual(LocalizedCopy.text(.positionRealizedPnL, language: .english), "RPNL")
        XCTAssertEqual(LocalizedCopy.text(.positionRealizedPnL, language: .chinese), "已实现盈亏")
        XCTAssertEqual(LocalizedCopy.text(.positionFundingFee, language: .english), "FUNDING")
        XCTAssertEqual(LocalizedCopy.text(.positionFundingFee, language: .chinese), "资金费")
    }

    func testAccountOverviewCarriesPartialSourceMessage() {
        let overview = AccountOverview(
            status: .warning,
            statusText: "ACCOUNT PARTIAL",
            usdEstimatedValue: 100,
            usdEstimatedChangeToday: nil,
            usdEstimatedChangePercentToday: nil,
            spotEstimatedValue: 100,
            usdMWalletBalance: nil,
            usdMUnrealizedPnL: nil,
            coinMWalletBalance: nil,
            coinMUnrealizedPnL: nil,
            positions: [],
            updatedAt: Date(timeIntervalSince1970: 100),
            message: "USD-M ACCOUNT: HTTP 403",
        )

        XCTAssertEqual(overview.status, .warning)
        XCTAssertEqual(overview.message, "USD-M ACCOUNT: HTTP 403")
    }

    func testExchangeSymbolMatchesSymbolBaseQuoteAndPair() {
        let symbol = ExchangeSymbol(
            symbol: "BTCUSDT",
            market: .spot,
            baseAsset: "BTC",
            quoteAsset: "USDT",
            status: "TRADING",
        )

        XCTAssertTrue(symbol.matches("btc"))
        XCTAssertTrue(symbol.matches("usdt"))
        XCTAssertTrue(symbol.matches("btc/usdt"))
        XCTAssertFalse(symbol.matches("eth"))
    }

    func testDiagnosticsReportIncludesStateWithoutSecretFields() {
        let report = DiagnosticsReport(
            generatedAt: Date(timeIntervalSince1970: 100),
            preferences: AppPreferences.defaults,
            tickers: [
                "spot:BTCUSDT": TickerSnapshot(
                    symbol: "BTCUSDT",
                    market: .spot,
                    lastPrice: 100,
                    priceChangePercent: 1,
                    updatedAt: Date(timeIntervalSince1970: 90),
                    status: .live,
                    message: nil,
                ),
            ],
            accountOverview: .notConfigured,
            apiKeyState: APIKeyState(hasKey: true, statusText: "KEY STORED"),
            lastError: "HTTP 429",
        )
        let text = report.redactedText

        XCTAssertTrue(text.contains("KEY STORED"))
        XCTAssertTrue(text.contains("HTTP 429"))
        XCTAssertTrue(text.contains("BTCUSDT"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("secret"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("signature"))
    }

    func testAppVersionComparesSemverTags() {
        XCTAssertLessThan(AppVersion("v0.1.0"), AppVersion("0.1.1"))
        XCTAssertLessThan(AppVersion("1.9.9"), AppVersion("1.10.0"))
        XCTAssertEqual(AppVersion("1.2"), AppVersion("1.2.0"))
    }

    func testAccountSnapshotHistoryFinds24hBaseline() {
        let now = Date(timeIntervalSince1970: 48 * 60 * 60)
        var history = AccountSnapshotHistory.empty
        history.record(AccountSnapshot(capturedAt: now.addingTimeInterval(-26 * 60 * 60), usdEstimatedValue: 90), now: now)
        history.record(AccountSnapshot(capturedAt: now.addingTimeInterval(-24 * 60 * 60), usdEstimatedValue: 100), now: now)
        history.record(AccountSnapshot(capturedAt: now.addingTimeInterval(-1 * 60 * 60), usdEstimatedValue: 110), now: now)

        XCTAssertEqual(history.baseline24h(now: now)?.usdEstimatedValue, 100)
    }
}

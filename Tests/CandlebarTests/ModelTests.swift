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
        XCTAssertEqual(preferences.headerIntradayInterval, .fifteenMinutes)
        XCTAssertEqual(preferences.watchlistIntradayInterval, .fifteenMinutes)
        XCTAssertEqual(preferences.headerChartDisplayMode, .fullDay)
        XCTAssertEqual(preferences.language, .english)
    }

    func testIntradayIntervalSlotsMatchFullTradingDay() {
        XCTAssertEqual(IntradayInterval.fifteenMinutes.slotsPerDay, 96)
        XCTAssertEqual(IntradayInterval.thirtyMinutes.slotsPerDay, 48)
        XCTAssertEqual(IntradayInterval.oneHour.slotsPerDay, 24)
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
            MenuBarLabelFormatter.text(item: item, ticker: nil, percentChange: nil, compact: false, decimalPlaces: 2),
            "BTC --",
        )
        XCTAssertEqual(
            MenuBarLabelFormatter.text(
                item: item,
                ticker: ticker,
                percentChange: Decimal(string: "5"),
                compact: false,
                decimalPlaces: 2,
            ),
            "BTC 123.45 +5.00%",
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

    func testIntradayChartKeepsGapForMissingCandleSlot() {
        let start = Date(timeIntervalSince1970: 1_788_019_200)
        let series = IntradaySeries(
            symbol: "BTCUSDT",
            market: .spot,
            dayStart: start,
            candles: [
                IntradayCandle(
                    openTime: start,
                    open: 100,
                    high: 101,
                    low: 99,
                    close: 100,
                ),
                IntradayCandle(
                    openTime: start.addingTimeInterval(IntradayInterval.fifteenMinutes.seconds * 2),
                    open: 100,
                    high: 103,
                    low: 98,
                    close: 102,
                ),
            ],
            updatedAt: start.addingTimeInterval(IntradayInterval.fifteenMinutes.seconds * 2),
            status: .live,
            message: nil,
        )

        let chart = IntradayChartData(series: series, currentPrice: nil)
        let leadSlots = Array(chart.visibleCandleSlots.prefix(3))

        XCTAssertEqual(chart.visibleCandleSlots.count, 96)
        XCTAssertNotNil(leadSlots[0])
        XCTAssertNil(leadSlots[1])
        XCTAssertNotNil(leadSlots[2])
    }

    func testIntradayChartShowsFullDayCandleSlots() {
        let start = Date(timeIntervalSince1970: 1_788_019_200)
        let latestOpenTime = start.addingTimeInterval(IntradayInterval.fifteenMinutes.seconds * 50)
        let series = IntradaySeries(
            symbol: "BTCUSDT",
            market: .spot,
            dayStart: start,
            candles: [
                IntradayCandle(
                    openTime: start,
                    open: 100,
                    high: 101,
                    low: 99,
                    close: 100,
                ),
                IntradayCandle(
                    openTime: latestOpenTime,
                    open: 100,
                    high: 106,
                    low: 98,
                    close: 105,
                ),
            ],
            updatedAt: latestOpenTime,
            status: .live,
            message: nil,
        )

        let chart = IntradayChartData(series: series, currentPrice: nil)

        XCTAssertEqual(chart.visibleCandleSlots.count, 96)
        XCTAssertEqual(chart.visibleCandleSlots.first??.openTime, start)
        XCTAssertEqual(chart.visibleCandleSlots[50]?.openTime, latestOpenTime)
    }

    func testIntradayChartUsesSeriesIntervalSlots() {
        let start = Date(timeIntervalSince1970: 1_788_019_200)
        let laterOpenTime = start.addingTimeInterval(IntradayInterval.thirtyMinutes.seconds * 20)
        let series = IntradaySeries(
            symbol: "BTCUSDT",
            market: .spot,
            interval: .thirtyMinutes,
            dayStart: start,
            candles: [
                IntradayCandle(
                    openTime: start,
                    open: 100,
                    high: 101,
                    low: 99,
                    close: 100,
                ),
                IntradayCandle(
                    openTime: laterOpenTime,
                    open: 100,
                    high: 106,
                    low: 98,
                    close: 105,
                ),
            ],
            updatedAt: laterOpenTime,
            status: .live,
            message: nil,
        )

        let chart = IntradayChartData(series: series, currentPrice: nil)

        XCTAssertEqual(chart.visibleCandleSlots.count, 48)
        XCTAssertEqual(chart.visibleCandleSlots[20]?.openTime, laterOpenTime)
    }

    func testIntradayChartElapsedDayModeUsesOnlyElapsedSlots() {
        let start = Date(timeIntervalSince1970: 1_788_019_200)
        let latestOpenTime = start.addingTimeInterval(IntradayInterval.fifteenMinutes.seconds * 20)
        let series = IntradaySeries(
            symbol: "BTCUSDT",
            market: .spot,
            dayStart: start,
            candles: [
                IntradayCandle(
                    openTime: start,
                    open: 100,
                    high: 101,
                    low: 99,
                    close: 100,
                ),
                IntradayCandle(
                    openTime: latestOpenTime,
                    open: 100,
                    high: 106,
                    low: 98,
                    close: 105,
                ),
            ],
            updatedAt: latestOpenTime,
            status: .live,
            message: nil,
        )

        let chart = IntradayChartData(series: series, currentPrice: nil, displayMode: .elapsedDay)

        XCTAssertEqual(chart.visibleCandleSlots.count, 21)
        XCTAssertEqual(chart.visibleCandleSlots.first??.openTime, start)
        XCTAssertEqual(chart.visibleCandleSlots.last??.openTime, latestOpenTime)
    }

    func testBinanceKlineQueryUsesSelectedInterval() {
        let item = WatchSymbol(symbol: "BTCUSDT", market: .spot)
        let service = BinanceKlineService()
        let now = Date(timeIntervalSince1970: 1_788_024_600)
        let values = Dictionary(
            uniqueKeysWithValues: service
                .intradayQueryItems(for: item, interval: .oneHour, now: now)
                .map { ($0.name, $0.value ?? "") },
        )

        XCTAssertEqual(values["symbol"], "BTCUSDT")
        XCTAssertEqual(values["interval"], "1h")
        XCTAssertEqual(values["limit"], "24")
    }

    func testDailySnapshotQueryUsesCompletedBinanceDayWindow() {
        let service = BinanceAccountService()
        let now = Int64(1_782_892_601_000)
        let items = service.dailySnapshotQueryItems(type: "SPOT", now: now)
        let values = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(values["type"], "SPOT")
        XCTAssertEqual(values["startTime"], "1782259200000")
        XCTAssertEqual(values["endTime"], "1782864000000")
        XCTAssertEqual(values["limit"], "7")
    }

    func testDailyAccountChangeUsesPreviousCompletedUTCDay() {
        let service = BinanceAccountService()
        let dayStart = Int64(1_782_864_000_000)
        let spotSnapshot = DailyAccountSnapshotPayload(
            code: 200,
            snapshotVos: [
                DailyAccountSnapshot(
                    data: DailyAccountSnapshotData(
                        balances: [DailySpotBalancePayload(asset: "USDT", free: "100", locked: "0")],
                        assets: nil,
                    ),
                    updateTime: dayStart - 86_400_000,
                ),
                DailyAccountSnapshot(
                    data: DailyAccountSnapshotData(
                        balances: [DailySpotBalancePayload(asset: "USDT", free: "125", locked: "0")],
                        assets: nil,
                    ),
                    updateTime: dayStart,
                ),
            ],
        )
        let futuresSnapshot = DailyAccountSnapshotPayload(
            code: 200,
            snapshotVos: [
                DailyAccountSnapshot(
                    data: DailyAccountSnapshotData(
                        balances: nil,
                        assets: [DailyFuturesAssetPayload(asset: "USDT", walletBalance: "200")],
                    ),
                    updateTime: dayStart - 86_400_000,
                ),
                DailyAccountSnapshot(
                    data: DailyAccountSnapshotData(
                        balances: nil,
                        assets: [DailyFuturesAssetPayload(asset: "USDT", walletBalance: "225")],
                    ),
                    updateTime: dayStart,
                ),
            ],
        )

        let change = service.dailyAccountChange(
            spotSnapshot: spotSnapshot,
            futuresSnapshot: futuresSnapshot,
            dayStart: dayStart,
        )

        XCTAssertEqual(change?.change, Decimal(50))
        XCTAssertEqual(change?.percent, Decimal(string: "16.66666666666666666666666666666666666667"))
    }

    func testIncomeHistoryQueryItemsUseSymbolTypeAndWindow() {
        let service = BinanceAccountService()
        let items = service.incomeHistoryQueryItems(
            symbol: "BTCUSDT",
            incomeType: "REALIZED_PNL",
            startTime: 1_775_116_601_000,
            endTime: 1_782_892_601_000,
        )
        let values = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(values["symbol"], "BTCUSDT")
        XCTAssertEqual(values["incomeType"], "REALIZED_PNL")
        XCTAssertEqual(values["startTime"], "1775116601000")
        XCTAssertEqual(values["endTime"], "1782892601000")
        XCTAssertEqual(values["limit"], "1000")
    }

    func testFuturesIncomeUsesNinetyDayNetRealizedPnLAndFundingOnly() async {
        MockURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let service = BinanceAccountService(session: URLSession(configuration: configuration))

        MockURLProtocol.handler = { request in
            let url = try XCTUnwrap(request.url)
            let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
            let query = Dictionary(uniqueKeysWithValues: components.queryItems?.map { ($0.name, $0.value ?? "") } ?? [])
            MockURLProtocol.record(url: url, query: query)

            let body: String
            switch components.path {
            case "/api/v3/time":
                body = #"{"serverTime":1782892601000}"#
            case "/api/v3/account":
                body = #"{"balances":[]}"#
            case "/fapi/v3/account":
                body = #"{"totalWalletBalance":"100","totalUnrealizedProfit":"0"}"#
            case "/fapi/v3/positionRisk":
                body = """
                [{
                  "symbol": "BTCUSDT",
                  "positionAmt": "1",
                  "entryPrice": "100",
                  "breakEvenPrice": "99",
                  "markPrice": "110",
                  "unRealizedProfit": "10",
                  "notional": "110",
                  "positionInitialMargin": "22",
                  "liquidationPrice": "50",
                  "leverage": "5",
                  "positionSide": "LONG"
                }]
                """
            case "/fapi/v1/symbolConfig":
                body = #"[{"symbol":"BTCUSDT","leverage":5}]"#
            case "/dapi/v1/account":
                body = #"{"totalWalletBalance":"0","totalUnrealizedProfit":"0"}"#
            case "/dapi/v1/positionRisk":
                body = #"[]"#
            case "/sapi/v1/accountSnapshot":
                body = #"{"code":200,"snapshotVos":[]}"#
            case "/fapi/v1/income":
                XCTAssertEqual(query["symbol"], "BTCUSDT")
                XCTAssertEqual(query["startTime"], "1775116601000")
                XCTAssertEqual(query["endTime"], "1782892601000")
                XCTAssertEqual(query["limit"], "1000")
                switch query["incomeType"] {
                case "REALIZED_PNL":
                    body = #"[{"symbol":"BTCUSDT","incomeType":"REALIZED_PNL","income":"340.34","time":1782892600000}]"#
                case "FUNDING_FEE":
                    body = #"[{"symbol":"BTCUSDT","incomeType":"FUNDING_FEE","income":"-29.62","time":1782892600000}]"#
                case "COMMISSION":
                    body = #"[{"symbol":"BTCUSDT","incomeType":"COMMISSION","income":"-1.09","time":1782892600000}]"#
                default:
                    body = #"[]"#
                }
            default:
                XCTFail("Unexpected request path: \(components.path)")
                body = #"{}"#
            }

            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"],
            )!
            return (response, Data(body.utf8))
        }

        let overview = await service.validate(credentials: StoredAPIKey(apiKey: "key", secret: "secret"))

        XCTAssertEqual(overview.positions.first?.realizedPnL, Decimal(string: "309.63"))
        XCTAssertEqual(overview.positions.first?.fundingFee, Decimal(string: "-29.62"))
        XCTAssertEqual(MockURLProtocol.recordedIncomeTypes, ["COMMISSION", "FUNDING_FEE", "REALIZED_PNL"])
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

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let state = MockURLProtocolState()

    static var handler: Handler? {
        get { state.handler }
        set { state.handler = newValue }
    }

    static var recordedIncomeTypes: [String] {
        state.recordedIncomeTypes
    }

    static func reset() {
        state.reset()
    }

    static func record(url: URL, query: [String: String]) {
        state.record(url: url, query: query)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let handler = try XCTUnwrap(Self.handler)
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class MockURLProtocolState: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [(url: URL, query: [String: String])] = []
    private var currentHandler: MockURLProtocol.Handler?

    var handler: MockURLProtocol.Handler? {
        get { lock.withLock { currentHandler } }
        set { lock.withLock { currentHandler = newValue } }
    }

    var recordedIncomeTypes: [String] {
        lock.withLock {
            requests
                .filter { $0.url.path == "/fapi/v1/income" }
                .compactMap { $0.query["incomeType"] }
                .sorted()
        }
    }

    func reset() {
        lock.withLock {
            requests = []
            currentHandler = nil
        }
    }

    func record(url: URL, query: [String: String]) {
        lock.withLock {
            requests.append((url: url, query: query))
        }
    }
}

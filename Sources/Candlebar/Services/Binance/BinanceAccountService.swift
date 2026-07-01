import CryptoKit
import Foundation

struct StoredAPIKey: Equatable {
    var apiKey: String
    var secret: String
}

final class BinanceAccountService: @unchecked Sendable {
    private static let stableAssets = Set(["USDT", "USDC", "FDUSD", "BUSD", "TUSD", "DAI"])
    private static let dailySnapshotLookbackDays: Int64 = 7
    private static let dailySnapshotLimit = 7
    private static let millisecondsPerDay: Int64 = 24 * 60 * 60 * 1000

    private let session: URLSession
    private var dailyBaselineCache: DailyAccountBaseline?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func validate(credentials: StoredAPIKey) async -> AccountOverview {
        guard !credentials.apiKey.isEmpty, !credentials.secret.isEmpty else {
            return .notConfigured
        }

        do {
            let serverTime = try await fetchServerTime()

            let spotAccount: SpotAccountPayload = try await signedRequest(
                baseURL: MarketType.spot.accountBaseURL,
                path: "/api/v3/account",
                credentials: credentials,
                timestamp: serverTime,
            )
            var sourceErrors: [String] = []
            let usdMAccount: FuturesAccountPayload? = await optionalSignedRequest(
                baseURL: MarketType.usdMFutures.accountBaseURL,
                path: "/fapi/v3/account",
                credentials: credentials,
                timestamp: serverTime,
                label: "USD-M ACCOUNT",
                errors: &sourceErrors,
            )
            let usdMPositions: [PositionRiskPayload] = await optionalSignedRequest(
                baseURL: MarketType.usdMFutures.accountBaseURL,
                path: "/fapi/v3/positionRisk",
                credentials: credentials,
                timestamp: serverTime,
                label: "USD-M POSITIONS",
                errors: &sourceErrors,
            ) ?? []
            let usdMSymbolConfigs: [SymbolConfigPayload] = await optionalSignedRequest(
                baseURL: MarketType.usdMFutures.accountBaseURL,
                path: "/fapi/v1/symbolConfig",
                credentials: credentials,
                timestamp: serverTime,
                label: "USD-M SYMBOL CONFIG",
                errors: &sourceErrors,
            ) ?? []
            let coinMAccount: CoinMAccountPayload? = await optionalSignedRequest(
                baseURL: MarketType.coinMFutures.accountBaseURL,
                path: "/dapi/v1/account",
                credentials: credentials,
                timestamp: serverTime,
                label: "COIN-M ACCOUNT",
                errors: &sourceErrors,
            )
            let coinMPositions: [PositionRiskPayload] = await optionalSignedRequest(
                baseURL: MarketType.coinMFutures.accountBaseURL,
                path: "/dapi/v1/positionRisk",
                credentials: credentials,
                timestamp: serverTime,
                label: "COIN-M POSITIONS",
                errors: &sourceErrors,
            ) ?? []
            let dailySnapshot = await cachedDailyAccountBaseline(
                credentials: credentials,
                now: serverTime,
                errors: &sourceErrors,
            )

            let usdMLeverageBySymbol = Dictionary(
                uniqueKeysWithValues: usdMSymbolConfigs.map { ($0.symbol, String($0.leverage)) },
            )
            let usdMIncomeBySymbol = await incomeTotalsBySymbol(
                market: .usdMFutures,
                symbols: activeSymbols(in: usdMPositions),
                credentials: credentials,
                timestamp: serverTime,
                errors: &sourceErrors,
            )
            let coinMIncomeBySymbol = await incomeTotalsBySymbol(
                market: .coinMFutures,
                symbols: activeSymbols(in: coinMPositions),
                credentials: credentials,
                timestamp: serverTime,
                errors: &sourceErrors,
            )
            let positions = activePositions(
                usdMPositions,
                market: .usdMFutures,
                leverageBySymbol: usdMLeverageBySymbol,
                incomeBySymbol: usdMIncomeBySymbol,
            ) + activePositions(
                coinMPositions,
                market: .coinMFutures,
                incomeBySymbol: coinMIncomeBySymbol,
            )
            let spotValue = spotEstimatedValue(from: spotAccount)
            let usdMWalletBalance = decimal(usdMAccount?.totalWalletBalance)
            let usdEstimatedValue = usdEstimatedValue(spotValue: spotValue, usdMWalletBalance: usdMWalletBalance)
            let todayChange = usdEstimatedChangeToday(current: usdEstimatedValue, baseline: dailySnapshot)

            return AccountOverview(
                status: sourceErrors.isEmpty ? .live : .warning,
                statusText: sourceErrors.isEmpty ? "ACCOUNT LIVE" : "ACCOUNT PARTIAL",
                usdEstimatedValue: usdEstimatedValue,
                usdEstimatedChangeToday: todayChange.change,
                usdEstimatedChangePercentToday: todayChange.percent,
                spotEstimatedValue: spotValue,
                usdMWalletBalance: usdMWalletBalance,
                usdMUnrealizedPnL: decimal(usdMAccount?.totalUnrealizedProfit),
                coinMWalletBalance: decimal(coinMAccount?.totalWalletBalance),
                coinMUnrealizedPnL: decimal(coinMAccount?.totalUnrealizedProfit),
                positions: positions,
                updatedAt: Date(),
                message: sourceErrors.joined(separator: " / "),
            )
        } catch let error as BinanceServiceError {
            return AccountOverview(
                status: .error,
                statusText: accountStatusText(for: error),
                usdEstimatedValue: nil,
                usdEstimatedChangeToday: nil,
                usdEstimatedChangePercentToday: nil,
                spotEstimatedValue: nil,
                usdMWalletBalance: nil,
                usdMUnrealizedPnL: nil,
                coinMWalletBalance: nil,
                coinMUnrealizedPnL: nil,
                positions: [],
                updatedAt: Date(),
                message: error.localizedDescription,
            )
        } catch {
            return AccountOverview(
                status: .offline,
                statusText: "OFFLINE",
                usdEstimatedValue: nil,
                usdEstimatedChangeToday: nil,
                usdEstimatedChangePercentToday: nil,
                spotEstimatedValue: nil,
                usdMWalletBalance: nil,
                usdMUnrealizedPnL: nil,
                coinMWalletBalance: nil,
                coinMUnrealizedPnL: nil,
                positions: [],
                updatedAt: Date(),
                message: error.localizedDescription,
            )
        }
    }

    private func fetchServerTime() async throws -> Int64 {
        let url = URL(string: "https://api.binance.com/api/v3/time")!
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw BinanceServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BinanceServiceError.httpStatus(http.statusCode)
        }
        let payload = try JSONDecoder().decode(ServerTimePayload.self, from: data)
        return payload.serverTime
    }

    private func signedRequest<T: Decodable>(
        baseURL: URL,
        path: String,
        queryItems: [URLQueryItem] = [],
        credentials: StoredAPIKey,
        timestamp: Int64,
    ) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        var items = queryItems
        items.append(URLQueryItem(name: "timestamp", value: String(timestamp)))
        items.append(URLQueryItem(name: "recvWindow", value: "5000"))
        let query = items
            .map { item in
                "\(item.name)=\(Self.percentEncodedQueryValue(item.value ?? ""))"
            }
            .joined(separator: "&")
        let signature = sign(query: query, secret: credentials.secret)
        components?.percentEncodedQuery = "\(query)&signature=\(signature)"
        guard let url = components?.url else {
            throw BinanceServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue(credentials.apiKey, forHTTPHeaderField: "X-MBX-APIKEY")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BinanceServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BinanceServiceError.httpStatus(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw BinanceServiceError.decodingFailed
        }
    }

    private func optionalSignedRequest<T: Decodable>(
        baseURL: URL,
        path: String,
        queryItems: [URLQueryItem] = [],
        credentials: StoredAPIKey,
        timestamp: Int64,
        label: String,
        errors: inout [String],
    ) async -> T? {
        do {
            return try await signedRequest(
                baseURL: baseURL,
                path: path,
                queryItems: queryItems,
                credentials: credentials,
                timestamp: timestamp,
            )
        } catch {
            errors.append("\(label): \(error.localizedDescription)")
            return nil
        }
    }

    private func sign(query: String, secret: String) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(query.utf8), using: key)
        return signature.map { String(format: "%02x", $0) }.joined()
    }

    private static func percentEncodedQueryValue(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":#[]@!$&'()*+,;=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func accountStatusText(for error: BinanceServiceError) -> String {
        switch error {
        case .httpStatus(401), .httpStatus(403):
            "KEY REJECTED"
        case .httpStatus(429), .httpStatus(418):
            "RATE LIMITED"
        case .decodingFailed:
            "DATA FORMAT CHANGED"
        case .missingCredentials:
            "READ-ONLY KEY NEEDED"
        case .invalidResponse, .signingUnavailable, .httpStatus:
            "ACCOUNT CHECK FAILED"
        }
    }

    private func spotEstimatedValue(from payload: SpotAccountPayload) -> Decimal? {
        let total = payload.balances.reduce(Decimal(0)) { partial, balance in
            guard Self.stableAssets.contains(balance.asset) else {
                return partial
            }
            return partial + (decimal(balance.free) ?? 0) + (decimal(balance.locked) ?? 0)
        }
        return total
    }

    private func usdEstimatedValue(spotValue: Decimal?, usdMWalletBalance: Decimal?) -> Decimal? {
        guard spotValue != nil || usdMWalletBalance != nil else {
            return nil
        }
        return (spotValue ?? 0) + (usdMWalletBalance ?? 0)
    }

    private func usdEstimatedChangeToday(
        current: Decimal?,
        baseline: DailyAccountBaseline?,
    ) -> (change: Decimal?, percent: Decimal?) {
        guard let current, let baseline else {
            return (nil, nil)
        }
        let change = current - baseline.usdEstimatedValue
        guard baseline.usdEstimatedValue != 0 else {
            return (change, nil)
        }
        return (change, (change / baseline.usdEstimatedValue) * 100)
    }

    private func cachedDailyAccountBaseline(
        credentials: StoredAPIKey,
        now: Int64,
        errors: inout [String],
    ) async -> DailyAccountBaseline? {
        let dayStart = utcDayStartMilliseconds(now)
        if let dailyBaselineCache, dailyBaselineCache.dayStart == dayStart {
            return dailyBaselineCache
        }

        let spotSnapshot: DailyAccountSnapshotPayload? = await optionalSignedRequest(
            baseURL: MarketType.spot.accountBaseURL,
            path: "/sapi/v1/accountSnapshot",
            queryItems: dailySnapshotQueryItems(type: "SPOT", now: now),
            credentials: credentials,
            timestamp: now,
            label: "SPOT DAILY SNAPSHOT",
            errors: &errors,
        )
        let futuresSnapshot: DailyAccountSnapshotPayload? = await optionalSignedRequest(
            baseURL: MarketType.spot.accountBaseURL,
            path: "/sapi/v1/accountSnapshot",
            queryItems: dailySnapshotQueryItems(type: "FUTURES", now: now),
            credentials: credentials,
            timestamp: now,
            label: "FUTURES DAILY SNAPSHOT",
            errors: &errors,
        )
        let spotValue = dailyAccountBaseline(spotSnapshot, before: dayStart)?.usdEstimatedValue
        let futuresValue = dailyAccountBaseline(futuresSnapshot, before: dayStart)?.usdEstimatedValue
        guard spotValue != nil || futuresValue != nil else {
            return nil
        }

        let baseline = DailyAccountBaseline(
            dayStart: dayStart,
            usdEstimatedValue: (spotValue ?? 0) + (futuresValue ?? 0),
        )
        dailyBaselineCache = baseline
        return baseline
    }

    func dailySnapshotQueryItems(type: String, now: Int64) -> [URLQueryItem] {
        let dayStart = utcDayStartMilliseconds(now)
        let startTime = max(0, dayStart - Self.dailySnapshotLookbackDays * Self.millisecondsPerDay)
        let endTime = max(0, dayStart - 1)
        return [
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "startTime", value: String(startTime)),
            URLQueryItem(name: "endTime", value: String(endTime)),
            URLQueryItem(name: "limit", value: String(Self.dailySnapshotLimit)),
        ]
    }

    private func utcDayStartMilliseconds(_ now: Int64) -> Int64 {
        let seconds = TimeInterval(now) / 1000
        let dayStart = Calendar.utc.startOfDay(for: Date(timeIntervalSince1970: seconds))
        return Int64(dayStart.timeIntervalSince1970 * 1000)
    }

    private func dailyAccountBaseline(
        _ payload: DailyAccountSnapshotPayload?,
        before dayStart: Int64,
    ) -> DailyAccountBaseline? {
        guard payload?.code == 200,
              let snapshot = payload?.snapshotVos
                .filter({ $0.updateTime < dayStart })
                .sorted(by: { $0.updateTime > $1.updateTime })
                .first else {
            return nil
        }
        let spotStableValue = snapshot.data.balances?.reduce(Decimal(0)) { partial, balance in
            guard Self.stableAssets.contains(balance.asset) else {
                return partial
            }
            return partial + (decimal(balance.free) ?? 0) + (decimal(balance.locked) ?? 0)
        }
        let usdMWalletBalance = snapshot.data.assets?.first { $0.asset == "USDT" }
            .flatMap { decimal($0.walletBalance) }
        guard spotStableValue != nil || usdMWalletBalance != nil else {
            return nil
        }
        return DailyAccountBaseline(
            dayStart: utcDayStartMilliseconds(snapshot.updateTime),
            usdEstimatedValue: (spotStableValue ?? 0) + (usdMWalletBalance ?? 0),
        )
    }

    private func activePositions(
        _ payloads: [PositionRiskPayload],
        market: MarketType,
        leverageBySymbol: [String: String] = [:],
        incomeBySymbol: [String: FuturesIncomeTotals] = [:],
    ) -> [FuturesPosition] {
        payloads.compactMap { payload in
            let quantity = decimal(payload.positionAmt) ?? 0
            guard quantity != 0 else {
                return nil
            }
            let income = incomeBySymbol[payload.symbol]
            return FuturesPosition(
                market: market,
                symbol: payload.symbol,
                side: payload.positionSide ?? (quantity > 0 ? "LONG" : "SHORT"),
                quantity: quantity,
                entryPrice: decimal(payload.entryPrice),
                markPrice: decimal(payload.markPrice),
                breakevenPrice: decimal(payload.breakEvenPrice),
                unrealizedPnL: decimal(payload.unRealizedProfit),
                realizedPnL: income?.realizedPnL,
                fundingFee: income?.fundingFee,
                notional: decimal(payload.notional) ?? decimal(payload.notionalValue),
                positionInitialMargin: decimal(payload.positionInitialMargin),
                liquidationPrice: decimal(payload.liquidationPrice),
                leverage: payload.leverage ?? leverageBySymbol[payload.symbol],
            )
        }
    }

    private func incomeTotalsBySymbol(
        market: MarketType,
        symbols: Set<String>,
        credentials: StoredAPIKey,
        timestamp: Int64,
        errors: inout [String],
    ) async -> [String: FuturesIncomeTotals] {
        guard !symbols.isEmpty else {
            return [:]
        }

        let path: String
        let label: String
        switch market {
        case .spot:
            return [:]
        case .usdMFutures:
            path = "/fapi/v1/income"
            label = "USD-M INCOME"
        case .coinMFutures:
            path = "/dapi/v1/income"
            label = "COIN-M INCOME"
        }

        let payloads: [IncomeHistoryPayload]? = await optionalSignedRequest(
            baseURL: market.accountBaseURL,
            path: path,
            queryItems: [
                URLQueryItem(name: "limit", value: "1000"),
            ],
            credentials: credentials,
            timestamp: timestamp,
            label: label,
            errors: &errors,
        )

        guard let payloads else {
            return [:]
        }

        var totals = Dictionary(uniqueKeysWithValues: symbols.map { ($0, FuturesIncomeTotals()) })
        payloads.forEach { payload in
            guard symbols.contains(payload.symbol) else {
                return
            }
            switch payload.incomeType {
            case "REALIZED_PNL":
                totals[payload.symbol, default: FuturesIncomeTotals()].realizedPnL += decimal(payload.income) ?? 0
            case "FUNDING_FEE":
                totals[payload.symbol, default: FuturesIncomeTotals()].fundingFee += decimal(payload.income) ?? 0
            default:
                return
            }
        }
        return totals
    }

    private func activeSymbols(in payloads: [PositionRiskPayload]) -> Set<String> {
        Set(payloads.compactMap { payload in
            let quantity = decimal(payload.positionAmt) ?? 0
            return quantity == 0 ? nil : payload.symbol
        })
    }

    private func decimal(_ value: String?) -> Decimal? {
        guard let value else {
            return nil
        }
        return Decimal(string: value)
    }
}

private struct ServerTimePayload: Decodable {
    let serverTime: Int64
}

private struct SpotAccountPayload: Decodable {
    let balances: [SpotBalancePayload]
}

private struct SpotBalancePayload: Decodable {
    let asset: String
    let free: String
    let locked: String
}

private struct FuturesAccountPayload: Decodable {
    let totalWalletBalance: String?
    let totalUnrealizedProfit: String?
}

private struct CoinMAccountPayload: Decodable {
    let totalWalletBalance: String?
    let totalUnrealizedProfit: String?
}

private struct PositionRiskPayload: Decodable {
    let symbol: String
    let positionAmt: String
    let entryPrice: String?
    let breakEvenPrice: String?
    let markPrice: String?
    let unRealizedProfit: String?
    let notional: String?
    let notionalValue: String?
    let positionInitialMargin: String?
    let liquidationPrice: String?
    let leverage: String?
    let positionSide: String?
}

private struct SymbolConfigPayload: Decodable {
    let symbol: String
    let leverage: Int
}

private struct IncomeHistoryPayload: Decodable {
    let symbol: String
    let incomeType: String
    let income: String
}

private struct FuturesIncomeTotals {
    var realizedPnL = Decimal(0)
    var fundingFee = Decimal(0)
}

private struct DailyAccountBaseline {
    let dayStart: Int64
    let usdEstimatedValue: Decimal
}

private struct DailyAccountSnapshotPayload: Decodable {
    let code: Int
    let snapshotVos: [DailyAccountSnapshot]
}

private struct DailyAccountSnapshot: Decodable {
    let data: DailyAccountSnapshotData
    let updateTime: Int64
}

private struct DailyAccountSnapshotData: Decodable {
    let balances: [DailySpotBalancePayload]?
    let assets: [DailyFuturesAssetPayload]?
}

private struct DailySpotBalancePayload: Decodable {
    let asset: String
    let free: String
    let locked: String
}

private struct DailyFuturesAssetPayload: Decodable {
    let asset: String
    let walletBalance: String
}

private extension Calendar {
    static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

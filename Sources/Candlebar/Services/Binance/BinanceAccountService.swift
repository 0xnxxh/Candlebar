import CryptoKit
import Foundation

struct StoredAPIKey: Equatable {
    var apiKey: String
    var secret: String
}

final class BinanceAccountService: @unchecked Sendable {
    private static let incomeLookbackDays: Int64 = 90
    private static let incomeHistoryLimit = 1000
    private static let millisecondsPerDay: Int64 = 24 * 60 * 60 * 1000

    private static let incomeOverlapMilliseconds: Int64 = 5 * 60 * 1000
    private static let maxConcurrentIncomeRequests = 4

    private let session: URLSession
    private let baselineStore: AccountBaselineStore
    private let clockLock = NSLock()
    private var serverClock: (time: Int64, uptime: TimeInterval)?
    private var incomeRecordCache: [IncomeCacheKey: [String: IncomeRecord]] = [:]
    private var incomeWatermark: [IncomeCacheKey: Int64] = [:]

    init(session: URLSession = .shared, baselineStore: AccountBaselineStore = AccountBaselineStore()) {
        self.session = session
        self.baselineStore = baselineStore
    }

    func validate(credentials: StoredAPIKey) async -> AccountOverview {
        guard !credentials.apiKey.isEmpty, !credentials.secret.isEmpty else {
            return .notConfigured
        }

        do {
            let serverTime = try await fetchServerTime()

            let walletPayload: [WalletBalancePayload] = try await signedRequest(
                baseURL: MarketType.spot.accountBaseURL,
                path: "/sapi/v1/asset/wallet/balance",
                queryItems: [URLQueryItem(name: "quoteAsset", value: "USDT")],
                credentials: credentials,
                timestamp: serverTime,
            )
            var wallets = try walletPayload.map { try $0.wallet() }
            guard !wallets.isEmpty, Set(wallets.map(\.name)).count == wallets.count else {
                throw BinanceServiceError.decodingFailed
            }
            let sampledAt = currentServerTime(fallback: serverTime)
            let total = wallets.reduce(Decimal(0)) { $0 + $1.value }
            var sourceErrors: [String] = []
            var baseline: AccountDailyBaseline?
            do {
                baseline = try baselineStore.baseline(wallets: wallets, apiKey: credentials.apiKey, now: sampledAt)
            } catch {
                sourceErrors.append("DAILY BASELINE: \(error.localizedDescription)")
            }
            let dailyChange = baseline?.change(current: wallets)
            if let dailyChange {
                for index in wallets.indices {
                    wallets[index].change = dailyChange.walletChanges[wallets[index].name]
                }
            }
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
            let coinMPositions: [PositionRiskPayload] = await optionalSignedRequest(
                baseURL: MarketType.coinMFutures.accountBaseURL,
                path: "/dapi/v1/positionRisk",
                credentials: credentials,
                timestamp: serverTime,
                label: "COIN-M POSITIONS",
                errors: &sourceErrors,
            ) ?? []
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
            return AccountOverview(
                status: sourceErrors.isEmpty ? .live : .warning,
                statusText: sourceErrors.isEmpty ? "ACCOUNT LIVE" : "ACCOUNT PARTIAL",
                usdEstimatedValue: total,
                usdtChange: dailyChange?.amount,
                usdtChangePercent: dailyChange?.percent,
                wallets: wallets,
                changeBaselineAt: dailyChange == nil ? nil : baseline?.sampledAt,
                changeBasis: dailyChange == nil ? nil : baseline?.basis,
                positions: positions,
                updatedAt: Date(timeIntervalSince1970: TimeInterval(sampledAt) / 1000),
                message: sourceErrors.joined(separator: " / "),
            )
        } catch let error as BinanceServiceError {
            return AccountOverview(
                status: .error,
                statusText: accountStatusText(for: error),
                usdEstimatedValue: nil,
                usdtChange: nil,
                usdtChangePercent: nil,
                positions: [],
                updatedAt: Date(),
                message: error.localizedDescription,
            )
        } catch {
            return AccountOverview(
                status: .offline,
                statusText: "OFFLINE",
                usdEstimatedValue: nil,
                usdtChange: nil,
                usdtChangePercent: nil,
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
        clockLock.withLock {
            serverClock = (payload.serverTime, ProcessInfo.processInfo.systemUptime)
        }
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
        items.append(URLQueryItem(name: "timestamp", value: String(currentServerTime(fallback: timestamp))))
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
        case .invalidResponse, .httpStatus:
            "ACCOUNT CHECK FAILED"
        }
    }

    // Signing timestamps must keep advancing during sequential account/income requests.
    private func currentServerTime(fallback: Int64) -> Int64 {
        clockLock.withLock {
            guard let serverClock else { return fallback }
            return serverClock.time + Int64(max(0, ProcessInfo.processInfo.systemUptime - serverClock.uptime) * 1000)
        }
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

    /// Income history is immutable once written, so each refresh only re-queries a short
    /// overlap window instead of the full 90-day lookback. Records are cached by transaction
    /// id and pruned to the lookback window, which keeps totals identical to a full rescan.
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

        let accountID = SHA256.hash(data: Data(credentials.apiKey.utf8)).map { String(format: "%02x", $0) }.joined()
        let windowStart = incomeHistoryStartTime(now: timestamp)
        let requests = symbols.sorted().map { symbol -> (symbol: String, startTime: Int64) in
            let key = IncomeCacheKey(accountID: accountID, market: market, symbol: symbol)
            guard let watermark = incomeWatermark[key] else {
                return (symbol, windowStart)
            }
            return (symbol, max(windowStart, watermark - Self.incomeOverlapMilliseconds))
        }

        let fetched = await withTaskGroup(
            of: (symbol: String, records: [IncomeRecord], errors: [String]).self,
        ) { group in
            var pending = requests.makeIterator()
            var inFlight = 0
            var collected: [(symbol: String, records: [IncomeRecord], errors: [String])] = []

            func addNext(
                to group: inout TaskGroup<(symbol: String, records: [IncomeRecord], errors: [String])>,
            ) {
                guard let request = pending.next() else { return }
                inFlight += 1
                group.addTask { [self] in
                    await fetchIncomeRecords(
                        symbol: request.symbol,
                        path: path,
                        label: label,
                        market: market,
                        credentials: credentials,
                        startTime: request.startTime,
                        endTime: timestamp,
                    )
                }
            }

            for _ in 0..<Self.maxConcurrentIncomeRequests {
                addNext(to: &group)
            }
            while inFlight > 0, let result = await group.next() {
                inFlight -= 1
                collected.append(result)
                addNext(to: &group)
            }
            return collected
        }

        let activeKeys = Set(symbols.map { IncomeCacheKey(accountID: accountID, market: market, symbol: $0) })
        incomeRecordCache = incomeRecordCache.filter { $0.key.market != market || activeKeys.contains($0.key) }
        incomeWatermark = incomeWatermark.filter { $0.key.market != market || activeKeys.contains($0.key) }

        var totals: [String: FuturesIncomeTotals] = [:]
        for result in fetched {
            errors.append(contentsOf: result.errors)
            let key = IncomeCacheKey(accountID: accountID, market: market, symbol: result.symbol)
            var records = incomeRecordCache[key] ?? [:]
            for record in result.records {
                records[record.id] = record
            }
            records = records.filter { $0.value.time >= windowStart }
            incomeRecordCache[key] = records
            if result.errors.isEmpty {
                incomeWatermark[key] = timestamp
            }

            var symbolTotals = FuturesIncomeTotals()
            for record in records.values {
                symbolTotals.add(record, decimal: decimal)
            }
            totals[result.symbol] = symbolTotals
        }
        return totals
    }

    private func fetchIncomeRecords(
        symbol: String,
        path: String,
        label: String,
        market: MarketType,
        credentials: StoredAPIKey,
        startTime: Int64,
        endTime: Int64,
    ) async -> (symbol: String, records: [IncomeRecord], errors: [String]) {
        var records: [IncomeRecord] = []
        var errors: [String] = []

        for incomeType in FuturesIncomeType.allCases {
            var pageStart = startTime
            while pageStart <= endTime {
                let payloads: [IncomeHistoryPayload]
                do {
                    payloads = try await signedRequest(
                        baseURL: market.accountBaseURL,
                        path: path,
                        queryItems: incomeHistoryQueryItems(
                            symbol: symbol,
                            incomeType: incomeType.rawValue,
                            startTime: pageStart,
                            endTime: endTime,
                        ),
                        credentials: credentials,
                        timestamp: endTime,
                    )
                } catch {
                    errors.append("\(label) \(symbol) \(incomeType.rawValue): \(error.localizedDescription)")
                    break
                }

                records.append(contentsOf: payloads.map(IncomeRecord.init(payload:)))
                guard payloads.count == Self.incomeHistoryLimit,
                      let nextTime = payloads.compactMap(\.time).max().map({ $0 + 1 }) else {
                    break
                }
                pageStart = nextTime
            }
        }
        return (symbol, records, errors)
    }

    func incomeHistoryQueryItems(
        symbol: String,
        incomeType: String,
        startTime: Int64,
        endTime: Int64,
    ) -> [URLQueryItem] {
        [
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "incomeType", value: incomeType),
            URLQueryItem(name: "startTime", value: String(startTime)),
            URLQueryItem(name: "endTime", value: String(endTime)),
            URLQueryItem(name: "limit", value: String(Self.incomeHistoryLimit)),
        ]
    }

    private func incomeHistoryStartTime(now: Int64) -> Int64 {
        max(0, now - Self.incomeLookbackDays * Self.millisecondsPerDay)
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

private struct WalletBalancePayload: Decodable {
    let walletName: String
    let balance: String
    let activate: Bool

    func wallet() throws -> AccountWallet {
        guard !walletName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              balance.range(of: #"^[+-]?[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil,
              let value = Decimal(string: balance, locale: Locale(identifier: "en_US_POSIX")),
              !value.isNaN else {
            throw BinanceServiceError.decodingFailed
        }
        return AccountWallet(name: walletName, value: value)
    }
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
    let time: Int64?
    let tranId: Int64?
}

private struct IncomeCacheKey: Hashable {
    let accountID: String
    let market: MarketType
    let symbol: String
}

private struct IncomeRecord: Sendable {
    let id: String
    let time: Int64
    let incomeType: String
    let income: String

    init(payload: IncomeHistoryPayload) {
        time = payload.time ?? 0
        incomeType = payload.incomeType
        income = payload.income
        if let tranId = payload.tranId {
            id = "\(payload.incomeType):\(tranId)"
        } else {
            id = "\(payload.incomeType):\(time):\(payload.income)"
        }
    }
}

private struct FuturesIncomeTotals {
    var realizedPnL = Decimal(0)
    var fundingFee = Decimal(0)

    mutating func add(_ record: IncomeRecord, decimal: (String?) -> Decimal?) {
        let amount = decimal(record.income) ?? 0
        switch record.incomeType {
        case FuturesIncomeType.realizedPnL.rawValue:
            realizedPnL += amount
        case FuturesIncomeType.fundingFee.rawValue:
            realizedPnL += amount
            fundingFee += amount
        case FuturesIncomeType.commission.rawValue:
            realizedPnL += amount
        default:
            return
        }
    }
}

private enum FuturesIncomeType: String, CaseIterable {
    case realizedPnL = "REALIZED_PNL"
    case fundingFee = "FUNDING_FEE"
    case commission = "COMMISSION"
}

import Foundation
import OSLog

@MainActor
final class AppStore: ObservableObject {
    @Published var preferences: AppPreferences
    @Published var tickers: [String: TickerSnapshot] = [:]
    @Published var accountOverview: AccountOverview = .notConfigured
    @Published var apiKeyState: APIKeyState = .missing
    @Published var isRefreshing = false
    @Published var isLoadingSymbols = false
    @Published var lastError: String?
    @Published var newSymbolDraft = ""
    @Published var newMarketDraft: MarketType = .spot
    @Published var symbolSearchResults: [ExchangeSymbol] = []
    @Published var apiKeyDraft = ""
    @Published var apiSecretDraft = ""
    @Published var diagnosticExport: String?
    var menuBarLabelDidChange: ((String) -> Void)?

    static let watchlistLimit = 30
    static let qaModeEnabled = ProcessInfo.processInfo.environment["CANDLEBAR_QA_WINDOW"] == "1"

    private let preferencesStore: PreferencesStore
    private let accountSnapshotStore: AccountSnapshotStore
    private let tickerService: BinanceTickerService
    private let symbolService: BinanceSymbolService
    private let accountService: BinanceAccountService
    private let keychainService: KeychainService
    private let logger = Logger(subsystem: "com.hoon.Candlebar", category: "AppStore")
    private var symbolCatalog: [MarketType: [ExchangeSymbol]] = [:]
    private var refreshTask: Task<Void, Never>?
    private var accountRefreshTask: Task<Void, Never>?
    private var streamTask: Task<Void, Never>?
    private var freshnessTask: Task<Void, Never>?
    private var symbolSearchTask: Task<Void, Never>?
    private static let tickerFallbackRefreshSeconds: Int64 = 10
    private static let accountRefreshSeconds: Int64 = 30

    init(
        preferencesStore: PreferencesStore = PreferencesStore(),
        accountSnapshotStore: AccountSnapshotStore = AccountSnapshotStore(),
        tickerService: BinanceTickerService = BinanceTickerService(),
        symbolService: BinanceSymbolService = BinanceSymbolService(),
        accountService: BinanceAccountService = BinanceAccountService(),
        keychainService: KeychainService = KeychainService(),
    ) {
        self.preferencesStore = preferencesStore
        self.accountSnapshotStore = accountSnapshotStore
        self.tickerService = tickerService
        self.symbolService = symbolService
        self.accountService = accountService
        self.keychainService = keychainService
        var loaded = preferencesStore.load()
        if loaded.defaultSymbolID == nil {
            loaded.defaultSymbolID = loaded.watchlist.first?.id
        }
        loaded.priceDecimalPlaces = min(8, max(0, loaded.priceDecimalPlaces))
        preferences = loaded
        loadAPIKeyState()
        start()
    }

    deinit {
        refreshTask?.cancel()
        accountRefreshTask?.cancel()
        streamTask?.cancel()
        freshnessTask?.cancel()
        symbolSearchTask?.cancel()
    }

    var defaultItem: WatchSymbol {
        if let id = preferences.defaultSymbolID,
           let item = preferences.watchlist.first(where: { $0.id == id }) {
            return item
        }
        return preferences.watchlist.first ?? WatchSymbol(symbol: "BTCUSDT", market: .spot)
    }

    var defaultTicker: TickerSnapshot? {
        tickers[defaultItem.cacheKey]
    }

    var menuBarLabelText: String {
        MenuBarLabelFormatter.text(
            item: defaultItem,
            ticker: defaultTicker,
            compact: preferences.compactMenuBar,
            decimalPlaces: preferences.priceDecimalPlaces,
        )
    }

    func start() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await refreshTickers()
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(Self.tickerFallbackRefreshSeconds))
                } catch {
                    return
                }
                await refreshTickers(onlyStale: true)
            }
        }
        startAccountRefreshLoop()
        startTickerStream()
        startFreshnessClock()
    }

    func refreshAll() async {
        await refreshTickers()
        await refreshAccount()
    }

    func refreshTickers(onlyStale: Bool = false) async {
        let now = Date()
        let items = preferences.watchlist.filter { item in
            guard onlyStale,
                  let existing = tickers[item.cacheKey],
                  let updatedAt = existing.updatedAt else {
                return true
            }
            return now.timeIntervalSince(updatedAt) >= Double(Self.tickerFallbackRefreshSeconds)
        }
        guard !items.isEmpty else {
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        for item in items {
            tickers[item.cacheKey] = tickers[item.cacheKey] ?? .loading(for: item)
        }

        for item in items {
            let result: (String, TickerSnapshot)
            do {
                let ticker = try await tickerService.fetchTicker(for: item)
                result = (item.cacheKey, ticker)
            } catch {
                result = (
                    item.cacheKey,
                    TickerSnapshot(
                        symbol: item.symbol,
                        market: item.market,
                        lastPrice: nil,
                        priceChangePercent: nil,
                        updatedAt: nil,
                        status: .error,
                        message: error.localizedDescription,
                    )
                )
            }
            tickers[result.0] = mergeStaleAware(new: result.1, existing: tickers[result.0])
            publishMenuBarLabel()
        }
    }

    func refreshAccount() async {
        guard !Self.qaModeEnabled else {
            apiKeyState = .missing
            accountOverview = .notConfigured
            return
        }
        guard let credentials = keychainService.loadCredentials() else {
            apiKeyState = .missing
            accountOverview = .notConfigured
            return
        }
        apiKeyState = APIKeyState(hasKey: true, statusText: "KEY STORED")
        let overview = await accountService.validate(credentials: credentials)
        accountOverview = accountOverviewWithSnapshot(overview)
    }

    func setDefault(_ item: WatchSymbol) {
        updatePreferences { $0.defaultSymbolID = item.id }
        publishMenuBarLabel()
    }

    func addSymbol(_ symbol: String, market: MarketType) {
        let normalized = symbol.normalizedSymbol
        guard !normalized.isEmpty else { return }
        guard preferences.watchlist.count < Self.watchlistLimit else {
            lastError = "WATCHLIST LIMIT \(Self.watchlistLimit)"
            return
        }
        let item = WatchSymbol(symbol: normalized, market: market)
        guard !preferences.watchlist.contains(where: { $0.symbol == item.symbol && $0.market == item.market }) else {
            lastError = "\(item.symbol) ALREADY ADDED"
            return
        }
        updatePreferences { preferences in
            preferences.watchlist.append(item)
            preferences.defaultSymbolID = preferences.defaultSymbolID ?? item.id
        }
        publishMenuBarLabel()
        startTickerStream()
        Task { await refreshTickers() }
    }

    func addDraftSymbol() {
        addSymbol(newSymbolDraft, market: newMarketDraft)
        newSymbolDraft = ""
        symbolSearchResults = []
    }

    func addSearchResult(_ result: ExchangeSymbol) {
        addSymbol(result.symbol, market: result.market)
        newSymbolDraft = ""
        symbolSearchResults = []
    }

    func updateNewSymbolDraft(_ value: String) {
        newSymbolDraft = value
        searchSymbols()
    }

    func updateNewMarketDraft(_ value: MarketType) {
        newMarketDraft = value
        searchSymbols(forceRefresh: symbolCatalog[value] == nil)
    }

    func removeSymbols(at offsets: IndexSet) {
        updatePreferences { preferences in
            preferences.watchlist.remove(atOffsets: offsets)
            if !preferences.watchlist.contains(where: { $0.id == preferences.defaultSymbolID }) {
                preferences.defaultSymbolID = preferences.watchlist.first?.id
            }
        }
        publishMenuBarLabel()
        startTickerStream()
    }

    func moveSymbols(from source: IndexSet, to destination: Int) {
        updatePreferences { $0.watchlist.move(fromOffsets: source, toOffset: destination) }
        publishMenuBarLabel()
    }

    func updateCompactMenuBar(_ value: Bool) {
        updatePreferences { $0.compactMenuBar = value }
        publishMenuBarLabel()
    }

    func updateHideBalances(_ value: Bool) {
        updatePreferences { $0.hideBalances = value }
    }

    func updateHideLowValueAccounts(_ value: Bool) {
        updatePreferences { $0.hideLowValueAccounts = value }
    }

    func updatePinMainPanel(_ value: Bool) {
        updatePreferences { $0.pinMainPanel = value }
    }

    func updatePixelTheme(_ value: Bool) {
        updatePreferences { $0.pixelTheme = value }
    }

    func updatePriceDecimalPlaces(_ value: Double) {
        updatePreferences { $0.priceDecimalPlaces = min(8, max(0, Int(value.rounded()))) }
        publishMenuBarLabel()
    }

    func updateLanguage(_ value: AppLanguage) {
        updatePreferences { $0.language = value }
        publishMenuBarLabel()
    }

    func saveAPIKey(apiKey: String, secret: String) {
        do {
            try keychainService.save(credentials: StoredAPIKey(apiKey: apiKey, secret: secret))
            loadAPIKeyState()
            apiSecretDraft = ""
            Task { await refreshAccount() }
        } catch {
            lastError = error.localizedDescription
            logger.error("Failed to save API key: \(error.localizedDescription, privacy: .public)")
        }
    }

    func saveDraftAPIKey() {
        saveAPIKey(apiKey: apiKeyDraft, secret: apiSecretDraft)
    }

    func deleteAPIKey() {
        keychainService.delete()
        accountSnapshotStore.clear()
        loadAPIKeyState()
        accountOverview = .notConfigured
        apiKeyDraft = ""
        apiSecretDraft = ""
    }

    func exportDiagnostics() {
        diagnosticExport = DiagnosticsReport(
            generatedAt: Date(),
            preferences: preferences,
            tickers: tickers,
            accountOverview: accountOverview,
            apiKeyState: apiKeyState,
            lastError: lastError,
        ).redactedText
    }

    private func loadAPIKeyState() {
        guard !Self.qaModeEnabled else {
            apiKeyState = .missing
            return
        }
        apiKeyState = keychainService.loadCredentials() == nil
            ? .missing
            : APIKeyState(hasKey: true, statusText: "KEY STORED")
    }

    private func persist() {
        preferencesStore.save(preferences)
    }

    private func updatePreferences(_ transform: (inout AppPreferences) -> Void) {
        var updated = preferences
        transform(&updated)
        preferences = updated
        persist()
    }

    private func publishMenuBarLabel() {
        menuBarLabelDidChange?(menuBarLabelText)
    }

    private func accountOverviewWithSnapshot(_ overview: AccountOverview) -> AccountOverview {
        guard let currentValue = overview.usdEstimatedValue else {
            return overview
        }
        let now = overview.updatedAt ?? Date()
        var history = accountSnapshotStore.load()
        history.record(AccountSnapshot(capturedAt: now, usdEstimatedValue: currentValue), now: now)
        accountSnapshotStore.save(history)
        return overview
    }

    private func searchSymbols(forceRefresh: Bool = false) {
        symbolSearchTask?.cancel()
        let market = newMarketDraft
        let query = newSymbolDraft
        symbolSearchTask = Task { [weak self] in
            guard let self else { return }
            let needsRefresh = await MainActor.run {
                forceRefresh || self.symbolCatalog[market] == nil
            }
            if needsRefresh {
                await MainActor.run {
                    self.isLoadingSymbols = true
                }
                do {
                    let symbols = try await symbolService.fetchSymbols(for: market)
                    await MainActor.run {
                        self.symbolCatalog[market] = symbols
                    }
                } catch {
                    await MainActor.run {
                        self.lastError = error.localizedDescription
                        self.symbolSearchResults = []
                        self.isLoadingSymbols = false
                    }
                    return
                }
            }

            await MainActor.run {
                self.symbolSearchResults = self.filteredSymbols(for: market, query: query)
                self.isLoadingSymbols = false
            }
        }
    }

    private func filteredSymbols(for market: MarketType, query: String) -> [ExchangeSymbol] {
        let symbols = symbolCatalog[market] ?? []
        let filtered = symbols.filter { candidate in
            candidate.matches(query)
                && !preferences.watchlist.contains {
                    $0.symbol == candidate.symbol && $0.market == candidate.market
                }
        }
        return Array(filtered.prefix(12))
    }

    private func startTickerStream() {
        streamTask?.cancel()
        let items = preferences.watchlist
        guard !items.isEmpty else {
            return
        }
        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await ticker in tickerService.streamTickers(for: items) {
                    await MainActor.run {
                        self.updateTicker(ticker)
                    }
                }
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                    self.markStreamOffline(message: error.localizedDescription)
                }
            }
        }
    }

    private func startAccountRefreshLoop() {
        accountRefreshTask?.cancel()
        accountRefreshTask = Task { [weak self] in
            guard let self else { return }
            await refreshAccount()
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(Self.accountRefreshSeconds))
                } catch {
                    return
                }
                await refreshAccount()
            }
        }
    }

    private func startFreshnessClock() {
        freshnessTask?.cancel()
        freshnessTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                await MainActor.run {
                    self.applyFreshness()
                }
            }
        }
    }

    private func mergeStaleAware(new: TickerSnapshot, existing: TickerSnapshot?) -> TickerSnapshot {
        var copy = new
        copy.movement = PriceMovement(previous: existing?.lastPrice, current: new.lastPrice)
        guard new.status == .error, let existing, existing.lastPrice != nil else {
            return copy
        }
        var stale = existing
        stale.status = .stale
        stale.message = new.message
        return stale
    }

    private func updateTicker(_ ticker: TickerSnapshot) {
        let key = "\(ticker.market.rawValue):\(ticker.symbol)"
        var copy = ticker
        copy.movement = PriceMovement(previous: tickers[key]?.lastPrice, current: ticker.lastPrice)
        tickers[key] = copy
        publishMenuBarLabel()
    }

    private func applyFreshness() {
        tickers = tickers.mapValues { $0.applyingFreshness() }
        publishMenuBarLabel()
    }

    private func markStreamOffline(message: String) {
        tickers = tickers.mapValues { ticker in
            var copy = ticker
            copy.status = .offline
            copy.message = message
            return copy
        }
        publishMenuBarLabel()
    }
}

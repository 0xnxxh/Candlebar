import Foundation

struct AppPreferences: Codable, Equatable {
    var watchlist: [WatchSymbol]
    var defaultSymbolID: UUID?
    var compactMenuBar: Bool
    var hideBalances: Bool
    var hideLowValueAccounts: Bool
    var pinMainPanel: Bool
    var showSidebar: Bool
    var sidebarEdge: SidebarEdge
    /// Vertical center of the rail as a fraction of the visible frame, 0 = top.
    var sidebarVerticalPosition: Double
    /// `CGDirectDisplayID` of the screen the rail was last docked to. `nil`
    /// until the user drags it, and ignored when that display is gone.
    var sidebarScreenNumber: UInt32?
    var showAccountRing: Bool
    var pixelTheme: Bool
    var priceDecimalPlaces: Int
    var headerIntradayInterval: IntradayInterval
    var watchlistIntradayInterval: IntradayInterval
    var headerChartDisplayMode: IntradayChartDisplayMode
    var language: AppLanguage

    enum CodingKeys: String, CodingKey {
        case watchlist
        case defaultSymbolID
        case compactMenuBar
        case hideBalances
        case hideLowValueAccounts
        case pinMainPanel
        case showSidebar
        case sidebarEdge
        case sidebarVerticalPosition
        case sidebarScreenNumber
        case showAccountRing
        case pixelTheme
        case priceDecimalPlaces
        case intradayInterval
        case headerIntradayInterval
        case watchlistIntradayInterval
        case headerChartDisplayMode
        case language
    }

    init(
        watchlist: [WatchSymbol],
        defaultSymbolID: UUID?,
        compactMenuBar: Bool,
        hideBalances: Bool,
        hideLowValueAccounts: Bool,
        pinMainPanel: Bool,
        showSidebar: Bool,
        sidebarEdge: SidebarEdge,
        sidebarVerticalPosition: Double,
        sidebarScreenNumber: UInt32?,
        showAccountRing: Bool,
        pixelTheme: Bool,
        priceDecimalPlaces: Int,
        headerIntradayInterval: IntradayInterval,
        watchlistIntradayInterval: IntradayInterval,
        headerChartDisplayMode: IntradayChartDisplayMode,
        language: AppLanguage,
    ) {
        self.watchlist = watchlist
        self.defaultSymbolID = defaultSymbolID
        self.compactMenuBar = compactMenuBar
        self.hideBalances = hideBalances
        self.hideLowValueAccounts = hideLowValueAccounts
        self.pinMainPanel = pinMainPanel
        self.showSidebar = showSidebar
        self.sidebarEdge = sidebarEdge
        self.sidebarVerticalPosition = sidebarVerticalPosition
        self.sidebarScreenNumber = sidebarScreenNumber
        self.showAccountRing = showAccountRing
        self.pixelTheme = pixelTheme
        self.priceDecimalPlaces = priceDecimalPlaces
        self.headerIntradayInterval = headerIntradayInterval
        self.watchlistIntradayInterval = watchlistIntradayInterval
        self.headerChartDisplayMode = headerChartDisplayMode
        self.language = language
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        watchlist = try container.decode([WatchSymbol].self, forKey: .watchlist)
        defaultSymbolID = try container.decodeIfPresent(UUID.self, forKey: .defaultSymbolID)
        compactMenuBar = try container.decode(Bool.self, forKey: .compactMenuBar)
        hideBalances = try container.decode(Bool.self, forKey: .hideBalances)
        hideLowValueAccounts = try container.decodeIfPresent(Bool.self, forKey: .hideLowValueAccounts) ?? false
        pinMainPanel = try container.decodeIfPresent(Bool.self, forKey: .pinMainPanel) ?? false
        showSidebar = try container.decodeIfPresent(Bool.self, forKey: .showSidebar) ?? false
        sidebarEdge = try container.decodeIfPresent(SidebarEdge.self, forKey: .sidebarEdge) ?? .right
        let storedPosition = try container.decodeIfPresent(Double.self, forKey: .sidebarVerticalPosition) ?? 0.5
        sidebarVerticalPosition = min(max(storedPosition, 0), 1)
        sidebarScreenNumber = try container.decodeIfPresent(UInt32.self, forKey: .sidebarScreenNumber)
        showAccountRing = try container.decodeIfPresent(Bool.self, forKey: .showAccountRing) ?? true
        pixelTheme = try container.decode(Bool.self, forKey: .pixelTheme)
        priceDecimalPlaces = try container.decode(Int.self, forKey: .priceDecimalPlaces)
        let legacyInterval = try container.decodeIfPresent(IntradayInterval.self, forKey: .intradayInterval) ?? .fifteenMinutes
        headerIntradayInterval = try container.decodeIfPresent(IntradayInterval.self, forKey: .headerIntradayInterval) ?? legacyInterval
        watchlistIntradayInterval = try container.decodeIfPresent(IntradayInterval.self, forKey: .watchlistIntradayInterval) ?? legacyInterval
        headerChartDisplayMode = try container.decodeIfPresent(IntradayChartDisplayMode.self, forKey: .headerChartDisplayMode) ?? .fullDay
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .english
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(watchlist, forKey: .watchlist)
        try container.encodeIfPresent(defaultSymbolID, forKey: .defaultSymbolID)
        try container.encode(compactMenuBar, forKey: .compactMenuBar)
        try container.encode(hideBalances, forKey: .hideBalances)
        try container.encode(hideLowValueAccounts, forKey: .hideLowValueAccounts)
        try container.encode(pinMainPanel, forKey: .pinMainPanel)
        try container.encode(showSidebar, forKey: .showSidebar)
        try container.encode(sidebarEdge, forKey: .sidebarEdge)
        try container.encode(sidebarVerticalPosition, forKey: .sidebarVerticalPosition)
        try container.encodeIfPresent(sidebarScreenNumber, forKey: .sidebarScreenNumber)
        try container.encode(showAccountRing, forKey: .showAccountRing)
        try container.encode(pixelTheme, forKey: .pixelTheme)
        try container.encode(priceDecimalPlaces, forKey: .priceDecimalPlaces)
        try container.encode(headerIntradayInterval, forKey: .headerIntradayInterval)
        try container.encode(watchlistIntradayInterval, forKey: .watchlistIntradayInterval)
        try container.encode(headerChartDisplayMode, forKey: .headerChartDisplayMode)
        try container.encode(language, forKey: .language)
    }

    static let defaults = AppPreferences(
        watchlist: [
            WatchSymbol(symbol: "BTCUSDT", market: .spot),
            WatchSymbol(symbol: "ETHUSDT", market: .spot),
            WatchSymbol(symbol: "SOLUSDT", market: .spot),
        ],
        defaultSymbolID: nil,
        compactMenuBar: false,
        hideBalances: false,
        hideLowValueAccounts: false,
        pinMainPanel: false,
        showSidebar: false,
        sidebarEdge: .right,
        sidebarVerticalPosition: 0.5,
        sidebarScreenNumber: nil,
        showAccountRing: true,
        pixelTheme: true,
        priceDecimalPlaces: 2,
        headerIntradayInterval: .fifteenMinutes,
        watchlistIntradayInterval: .fifteenMinutes,
        headerChartDisplayMode: .fullDay,
        language: .english,
    )
}

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case english
    case chinese

    var id: Self { self }

    var title: String {
        switch self {
        case .english: "EN"
        case .chinese: "中文"
        }
    }
}

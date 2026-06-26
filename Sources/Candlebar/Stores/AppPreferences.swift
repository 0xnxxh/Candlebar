import Foundation

struct AppPreferences: Codable, Equatable {
    var watchlist: [WatchSymbol]
    var defaultSymbolID: UUID?
    var compactMenuBar: Bool
    var hideBalances: Bool
    var hideLowValueAccounts: Bool
    var pinMainPanel: Bool
    var pixelTheme: Bool
    var priceDecimalPlaces: Int
    var language: AppLanguage

    enum CodingKeys: String, CodingKey {
        case watchlist
        case defaultSymbolID
        case compactMenuBar
        case hideBalances
        case hideLowValueAccounts
        case pinMainPanel
        case pixelTheme
        case priceDecimalPlaces
        case language
    }

    init(
        watchlist: [WatchSymbol],
        defaultSymbolID: UUID?,
        compactMenuBar: Bool,
        hideBalances: Bool,
        hideLowValueAccounts: Bool,
        pinMainPanel: Bool,
        pixelTheme: Bool,
        priceDecimalPlaces: Int,
        language: AppLanguage,
    ) {
        self.watchlist = watchlist
        self.defaultSymbolID = defaultSymbolID
        self.compactMenuBar = compactMenuBar
        self.hideBalances = hideBalances
        self.hideLowValueAccounts = hideLowValueAccounts
        self.pinMainPanel = pinMainPanel
        self.pixelTheme = pixelTheme
        self.priceDecimalPlaces = priceDecimalPlaces
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
        pixelTheme = try container.decode(Bool.self, forKey: .pixelTheme)
        priceDecimalPlaces = try container.decode(Int.self, forKey: .priceDecimalPlaces)
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .english
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
        pixelTheme: true,
        priceDecimalPlaces: 2,
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

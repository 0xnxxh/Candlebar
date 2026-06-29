import Foundation

enum MarketType: String, CaseIterable, Codable, Identifiable {
    case spot
    case usdMFutures
    case coinMFutures

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .spot: "SPOT"
        case .usdMFutures: "USD-M"
        case .coinMFutures: "COIN-M"
        }
    }

    var displayName: String {
        switch self {
        case .spot: "Spot"
        case .usdMFutures: "USD-M Futures"
        case .coinMFutures: "COIN-M Futures"
        }
    }

    var tickerBaseURL: URL {
        switch self {
        case .spot:
            URL(string: "https://api.binance.com/api/v3/ticker/24hr")!
        case .usdMFutures:
            URL(string: "https://fapi.binance.com/fapi/v1/ticker/24hr")!
        case .coinMFutures:
            URL(string: "https://dapi.binance.com/dapi/v1/ticker/24hr")!
        }
    }

    var klineURL: URL {
        switch self {
        case .spot:
            URL(string: "https://api.binance.com/api/v3/klines")!
        case .usdMFutures:
            URL(string: "https://fapi.binance.com/fapi/v1/klines")!
        case .coinMFutures:
            URL(string: "https://dapi.binance.com/dapi/v1/klines")!
        }
    }

    var exchangeInfoURL: URL {
        switch self {
        case .spot:
            URL(string: "https://api.binance.com/api/v3/exchangeInfo")!
        case .usdMFutures:
            URL(string: "https://fapi.binance.com/fapi/v1/exchangeInfo")!
        case .coinMFutures:
            URL(string: "https://dapi.binance.com/dapi/v1/exchangeInfo")!
        }
    }

    var accountBaseURL: URL {
        switch self {
        case .spot:
            URL(string: "https://api.binance.com")!
        case .usdMFutures:
            URL(string: "https://fapi.binance.com")!
        case .coinMFutures:
            URL(string: "https://dapi.binance.com")!
        }
    }

    var streamBaseURL: URL {
        switch self {
        case .spot:
            URL(string: "wss://stream.binance.com:9443/stream")!
        case .usdMFutures:
            URL(string: "wss://fstream.binance.com/market/stream")!
        case .coinMFutures:
            URL(string: "wss://dstream.binance.com/stream")!
        }
    }
}

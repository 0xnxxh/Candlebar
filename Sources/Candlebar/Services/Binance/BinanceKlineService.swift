import Foundation

struct BinanceKlinePayload: Decodable {
    let openTime: Int64
    let open: String
    let high: String
    let low: String
    let close: String

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        openTime = try container.decode(Int64.self)
        open = try container.decode(String.self)
        high = try container.decode(String.self)
        low = try container.decode(String.self)
        close = try container.decode(String.self)
    }
}

final class BinanceKlineService: @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchIntradaySeries(for item: WatchSymbol, now: Date = Date()) async throws -> IntradaySeries {
        let dayStart = UTCTradingDay.start(of: now)
        var components = URLComponents(url: item.market.klineURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "symbol", value: item.symbol),
            URLQueryItem(name: "interval", value: "15m"),
            URLQueryItem(name: "startTime", value: "\(UTCTradingDay.millisecondsSince1970(for: dayStart))"),
            URLQueryItem(name: "endTime", value: "\(UTCTradingDay.millisecondsSince1970(for: now))"),
            URLQueryItem(name: "limit", value: "96"),
        ]
        guard let url = components?.url else {
            throw BinanceServiceError.invalidResponse
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw BinanceServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BinanceServiceError.httpStatus(http.statusCode)
        }
        guard let payloads = try? JSONDecoder().decode([BinanceKlinePayload].self, from: data) else {
            throw BinanceServiceError.decodingFailed
        }

        return IntradaySeries(
            symbol: item.symbol,
            market: item.market,
            dayStart: dayStart,
            candles: payloads.compactMap(Self.candle(from:)),
            updatedAt: now,
            status: .live,
            message: nil,
        )
    }

    private static func candle(from payload: BinanceKlinePayload) -> IntradayCandle? {
        guard let open = Decimal(string: payload.open),
              let high = Decimal(string: payload.high),
              let low = Decimal(string: payload.low),
              let close = Decimal(string: payload.close) else {
            return nil
        }
        return IntradayCandle(
            openTime: Date(timeIntervalSince1970: TimeInterval(payload.openTime) / 1000),
            open: open,
            high: high,
            low: low,
            close: close,
        )
    }
}

import Foundation

struct BinanceTickerPayload: Decodable {
    let symbol: String
    let lastPrice: String
    let priceChangePercent: String
    let closeTime: Int?
}

struct BinanceStreamEnvelope: Decodable {
    let data: BinanceMiniTickerPayload
}

struct BinanceMiniTickerPayload: Decodable {
    let eventType: String?
    let symbol: String
    let closePrice: String
    let openPrice: String

    enum CodingKeys: String, CodingKey {
        case eventType = "e"
        case symbol = "s"
        case closePrice = "c"
        case openPrice = "o"
    }
}

enum BinanceServiceError: Error, LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case decodingFailed
    case missingCredentials
    case signingUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid response"
        case .httpStatus(let status): "HTTP \(status)"
        case .decodingFailed: "Data format changed"
        case .missingCredentials: "Missing API key"
        case .signingUnavailable: "Signing unavailable"
        }
    }
}

final class BinanceTickerService: @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchTicker(for item: WatchSymbol) async throws -> TickerSnapshot {
        var components = URLComponents(url: item.market.tickerBaseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "symbol", value: item.symbol),
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
        guard let payload = try? JSONDecoder().decode(BinanceTickerPayload.self, from: data) else {
            throw BinanceServiceError.decodingFailed
        }

        return TickerSnapshot(
            symbol: payload.symbol,
            market: item.market,
            lastPrice: Decimal(string: payload.lastPrice),
            priceChangePercent: Decimal(string: payload.priceChangePercent),
            updatedAt: Date(),
            status: .live,
            message: nil,
        )
    }

    func streamTickers(for items: [WatchSymbol]) -> AsyncThrowingStream<TickerSnapshot, Error> {
        AsyncThrowingStream { continuation in
            let groups = groupedByMarket(items)
            let task = Task {
                await withTaskGroup(of: Void.self) { taskGroup in
                    for group in groups {
                        taskGroup.addTask { [self] in
                            await runMarketStream(group, continuation: continuation)
                        }
                    }
                    await taskGroup.waitForAll()
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func runMarketStream(
        _ items: [WatchSymbol],
        continuation: AsyncThrowingStream<TickerSnapshot, Error>.Continuation,
    ) async {
        while !Task.isCancelled {
            do {
                try await streamMarket(items, continuation: continuation)
            } catch is CancellationError {
                return
            } catch {
                offlineSnapshots(for: items, message: error.localizedDescription).forEach {
                    continuation.yield($0)
                }
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func streamMarket(
        _ items: [WatchSymbol],
        continuation: AsyncThrowingStream<TickerSnapshot, Error>.Continuation,
    ) async throws {
        guard let first = items.first else {
            return
        }
        let streams = items
            .map { "\($0.symbol.lowercased())@miniTicker" }
            .joined(separator: "/")
        var components = URLComponents(url: first.market.streamBaseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "streams", value: streams)]
        guard let url = components?.url else {
            throw BinanceServiceError.invalidResponse
        }

        let socket = session.webSocketTask(with: url)
        socket.resume()

        do {
            while !Task.isCancelled {
                let message = try await socket.receive()
                switch message {
                case .string(let text):
                    if let snapshot = decodeStream(text, market: first.market) {
                        continuation.yield(snapshot)
                    }
                case .data(let data):
                    if let snapshot = decodeStream(data, market: first.market) {
                        continuation.yield(snapshot)
                    }
                @unknown default:
                    throw BinanceServiceError.invalidResponse
                }
            }
        } catch {
            socket.cancel(with: .goingAway, reason: nil)
            throw error
        }
        socket.cancel(with: .goingAway, reason: nil)
    }

    private func groupedByMarket(_ items: [WatchSymbol]) -> [[WatchSymbol]] {
        Dictionary(grouping: items, by: \.market)
            .values
            .map(Array.init)
    }

    private func offlineSnapshots(for items: [WatchSymbol], message: String) -> [TickerSnapshot] {
        items.map { item in
            TickerSnapshot(
                symbol: item.symbol,
                market: item.market,
                lastPrice: nil,
                priceChangePercent: nil,
                updatedAt: Date(),
                status: .offline,
                message: message,
            )
        }
    }

    private func decodeStream(_ text: String, market: MarketType) -> TickerSnapshot? {
        decodeStream(Data(text.utf8), market: market)
    }

    private func decodeStream(_ data: Data, market: MarketType) -> TickerSnapshot? {
        guard let envelope = try? JSONDecoder().decode(BinanceStreamEnvelope.self, from: data) else {
            return nil
        }
        let close = Decimal(string: envelope.data.closePrice)
        let open = Decimal(string: envelope.data.openPrice)
        let changePercent = percentChange(open: open, close: close)
        return TickerSnapshot(
            symbol: envelope.data.symbol,
            market: market,
            lastPrice: close,
            priceChangePercent: changePercent,
            updatedAt: Date(),
            status: .live,
            message: nil,
        )
    }

    private func percentChange(open: Decimal?, close: Decimal?) -> Decimal? {
        guard let open, let close, open != 0 else {
            return nil
        }
        return ((close - open) / open) * 100
    }
}

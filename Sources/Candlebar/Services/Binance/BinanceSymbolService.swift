import Foundation

struct BinanceExchangeInfoPayload: Decodable {
    let symbols: [BinanceExchangeSymbolPayload]
}

struct BinanceExchangeSymbolPayload: Decodable {
    let symbol: String
    let status: String
    let baseAsset: String?
    let quoteAsset: String?
    let marginAsset: String?
}

final class BinanceSymbolService: @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchSymbols(for market: MarketType) async throws -> [ExchangeSymbol] {
        let (data, response) = try await session.data(from: market.exchangeInfoURL)
        guard let http = response as? HTTPURLResponse else {
            throw BinanceServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BinanceServiceError.httpStatus(http.statusCode)
        }

        do {
            let payload = try JSONDecoder().decode(BinanceExchangeInfoPayload.self, from: data)
            return payload.symbols
                .compactMap { exchangeSymbol(from: $0, market: market) }
                .sorted { $0.symbol < $1.symbol }
        } catch {
            throw BinanceServiceError.decodingFailed
        }
    }

    private func exchangeSymbol(
        from payload: BinanceExchangeSymbolPayload,
        market: MarketType,
    ) -> ExchangeSymbol? {
        guard payload.status == "TRADING" else {
            return nil
        }
        guard let baseAsset = payload.baseAsset?.normalizedSymbol, !baseAsset.isEmpty else {
            return nil
        }
        let quoteAsset = payload.quoteAsset?.normalizedSymbol
            ?? payload.marginAsset?.normalizedSymbol
            ?? ""

        return ExchangeSymbol(
            symbol: payload.symbol.normalizedSymbol,
            market: market,
            baseAsset: baseAsset,
            quoteAsset: quoteAsset,
            status: payload.status,
        )
    }
}

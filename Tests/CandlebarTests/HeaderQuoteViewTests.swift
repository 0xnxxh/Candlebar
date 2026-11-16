import AppKit
import SwiftUI
import Vision
import XCTest
@testable import Candlebar

final class HeaderQuoteViewTests: XCTestCase {
    @MainActor
    func testHeaderShowsFullFormattedPrice() throws {
        let dayStart = UTCTradingDay.start(of: Date())
        let series = IntradaySeries(
            symbol: "BTCUSDT",
            market: .usdMFutures,
            dayStart: dayStart,
            candles: [
                IntradayCandle(openTime: dayStart, open: 100, high: 110, low: 90, close: 105),
                IntradayCandle(openTime: dayStart.addingTimeInterval(900), open: 105, high: 108, low: 95, close: 99),
            ],
            updatedAt: dayStart,
            status: .live,
            message: nil,
        )

        for price in ["64,670.00", "64,670.12345678", "0.00000001", "123,456,789.12345678"] {
            let view = HeaderQuoteView(
                price: price,
                movement: .flat,
                series: series,
                currentPrice: nil,
                displayMode: .fullDay,
                percent: Decimal(string: "-0.95"),
            )
            .frame(width: 352)
            .foregroundStyle(PixelColors.text)
            .background(PixelColors.raised)

            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.cgImage)
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            try VNImageRequestHandler(cgImage: image).perform([request])
            let recognized = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ")
                .replacingOccurrences(of: " ", with: "")
            XCTAssertTrue(recognized.contains(price), "Expected \(price), recognized \(recognized)")
            XCTAssertTrue(recognized.contains("95%"), "Expected percentage, recognized \(recognized)")
        }
    }
}

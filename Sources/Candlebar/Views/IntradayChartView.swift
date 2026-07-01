import SwiftUI

struct IntradayCandlestickView: View {
    var series: IntradaySeries?
    var currentPrice: Decimal?
    var displayMode: IntradayChartDisplayMode
    var tint: Color

    var body: some View {
        Canvas { context, size in
            let chart = IntradayChartData(series: series, currentPrice: currentPrice, displayMode: displayMode)
            guard chart.hasValues else {
                drawEmptyState(context: context, size: size)
                return
            }
            drawBaseline(context: context, size: size, chart: chart)
            drawCandles(context: context, size: size, chart: chart)
        }
        .frame(minWidth: 130, minHeight: 68)
        .help("UTC 00:00 intraday candlesticks")
    }

    private func drawEmptyState(context: GraphicsContext, size: CGSize) {
        var line = Path()
        line.move(to: CGPoint(x: 0, y: size.height / 2))
        line.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        context.stroke(line, with: .color(PixelColors.line.opacity(0.55)), lineWidth: 1)
    }

    private func drawBaseline(context: GraphicsContext, size: CGSize, chart: IntradayChartData) {
        guard let baselineY = chart.y(for: chart.baseline, in: size) else {
            return
        }
        var line = Path()
        line.move(to: CGPoint(x: 0, y: baselineY))
        line.addLine(to: CGPoint(x: size.width, y: baselineY))
        context.stroke(line, with: .color(tint.opacity(0.45)), lineWidth: 1)
    }

    private func drawCandles(context: GraphicsContext, size: CGSize, chart: IntradayChartData) {
        let candleSlots = chart.visibleCandleSlots
        guard !candleSlots.isEmpty else {
            return
        }
        let slot = size.width / CGFloat(candleSlots.count)
        let bodyWidth = max(1, min(6, slot * 0.72))

        for index in candleSlots.indices {
            guard let candle = candleSlots[index] else {
                continue
            }
            let centerX = slot * CGFloat(index) + slot / 2
            guard let highY = chart.y(for: candle.high, in: size),
                  let lowY = chart.y(for: candle.low, in: size),
                  let openY = chart.y(for: candle.open, in: size),
                  let closeY = chart.y(for: candle.close, in: size) else {
                continue
            }
            let color = candle.close >= candle.open ? PixelColors.up : PixelColors.down
            var wick = Path()
            wick.move(to: CGPoint(x: centerX, y: highY))
            wick.addLine(to: CGPoint(x: centerX, y: lowY))
            context.stroke(wick, with: .color(color.opacity(0.9)), lineWidth: 1)

            let bodyTop = min(openY, closeY)
            let bodyHeight = max(2, abs(closeY - openY))
            let rect = CGRect(
                x: centerX - bodyWidth / 2,
                y: bodyTop,
                width: bodyWidth,
                height: bodyHeight,
            )
            context.fill(Path(rect), with: .color(color))
        }
    }
}

struct IntradaySparklineView: View {
    var series: IntradaySeries?
    var currentPrice: Decimal?
    var tint: Color

    var body: some View {
        Canvas { context, size in
            let chart = IntradayChartData(series: series, currentPrice: currentPrice)
            guard chart.hasValues else {
                drawEmptyState(context: context, size: size)
                return
            }
            drawBaseline(context: context, size: size, chart: chart)
            drawSparkline(context: context, size: size, chart: chart)
        }
        .frame(minWidth: 64, minHeight: 32)
        .help("UTC 00:00 intraday curve")
    }

    private func drawEmptyState(context: GraphicsContext, size: CGSize) {
        var line = Path()
        line.move(to: CGPoint(x: 0, y: size.height / 2))
        line.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        context.stroke(line, with: .color(PixelColors.line.opacity(0.45)), lineWidth: 1)
    }

    private func drawBaseline(context: GraphicsContext, size: CGSize, chart: IntradayChartData) {
        guard let baselineY = chart.y(for: chart.baseline, in: size) else {
            return
        }
        var line = Path()
        line.move(to: CGPoint(x: 0, y: baselineY))
        line.addLine(to: CGPoint(x: size.width, y: baselineY))
        context.stroke(line, with: .color(PixelColors.line.opacity(0.7)), lineWidth: 1)
    }

    private func drawSparkline(context: GraphicsContext, size: CGSize, chart: IntradayChartData) {
        let closeSlots = chart.visibleCloseSlots
        guard closeSlots.compactMap({ $0 }).count > 1 else {
            return
        }
        let step = size.width / CGFloat(max(1, closeSlots.count - 1))
        var path = Path()
        var hasSegment = false
        for index in closeSlots.indices {
            guard let close = closeSlots[index],
                  let y = chart.y(for: close, in: size) else {
                hasSegment = false
                continue
            }
            let point = CGPoint(x: CGFloat(index) * step, y: y)
            if hasSegment {
                path.addLine(to: point)
            } else {
                path.move(to: point)
                hasSegment = true
            }
        }
        context.stroke(path, with: .color(tint), lineWidth: 2)
    }
}

struct IntradayChartData {
    private static let maxVisiblePoints = 48
    private static let verticalInset: CGFloat = 3

    let baseline: Decimal
    let visibleCandleSlots: [IntradayCandle?]
    let visibleCloseSlots: [Decimal?]
    let visibleCloses: [Decimal]
    private let minValue: Decimal
    private let maxValue: Decimal

    init(
        series: IntradaySeries?,
        currentPrice: Decimal?,
        displayMode: IntradayChartDisplayMode = .fullDay,
    ) {
        let candles = series?.candles ?? []
        let baseline = series?.baselineOpen ?? currentPrice ?? 0
        var adjustedCandles = candles
        if let currentPrice, var last = adjustedCandles.last {
            last.close = currentPrice
            last.high = max(last.high, currentPrice)
            last.low = min(last.low, currentPrice)
            adjustedCandles[adjustedCandles.count - 1] = last
        }

        self.baseline = baseline
        visibleCandleSlots = Self.visibleCandleSlots(
            adjustedCandles,
            dayStart: series?.dayStart,
            interval: series?.interval ?? .fifteenMinutes,
            displayMode: displayMode,
        )
        visibleCloseSlots = visibleCandleSlots.map { $0?.close }
        var closes = Self.sample(adjustedCandles.map(\.close), limit: Self.maxVisiblePoints)
        if closes.count == 1 {
            closes.append(closes[0])
        }
        visibleCloses = closes

        let candleValues = adjustedCandles.flatMap { [$0.high, $0.low, $0.open, $0.close] }
        let values = candleValues + [baseline] + [currentPrice].compactMap { $0 }
        minValue = values.min() ?? baseline
        maxValue = values.max() ?? baseline
    }

    var hasValues: Bool {
        visibleCandleSlots.contains { $0 != nil } || !visibleCloses.isEmpty
    }

    func y(for value: Decimal, in size: CGSize) -> CGFloat? {
        let minimum = double(minValue)
        let maximum = double(maxValue)
        let current = double(value)
        guard maximum.isFinite, minimum.isFinite, current.isFinite else {
            return nil
        }
        let range = max(maximum - minimum, abs(maximum) * 0.002, 0.000001)
        let ratio = (current - minimum) / range
        let drawableHeight = max(1, size.height - Self.verticalInset * 2)
        return size.height - Self.verticalInset - CGFloat(ratio) * drawableHeight
    }

    private static func sample<T>(_ values: [T], limit: Int) -> [T] {
        guard values.count > limit, limit > 1 else {
            return values
        }
        return (0..<limit).map { index in
            let sourceIndex = Int((Double(index) / Double(limit - 1)) * Double(values.count - 1))
            return values[sourceIndex]
        }
    }

    private static func visibleCandleSlots(
        _ candles: [IntradayCandle],
        dayStart: Date?,
        interval: IntradayInterval,
        displayMode: IntradayChartDisplayMode,
    ) -> [IntradayCandle?] {
        guard let firstOpenTime = dayStart ?? candles.first?.openTime else {
            return []
        }

        let firstSlot = slotIndex(for: firstOpenTime, interval: interval)
        let lastSlot = Self.lastVisibleSlot(
            firstSlot: firstSlot,
            candles: candles,
            interval: interval,
            displayMode: displayMode,
        )
        let candleBySlot = Dictionary(
            candles.map { (slotIndex(for: $0.openTime, interval: interval), $0) },
            uniquingKeysWith: { _, last in last },
        )

        return (firstSlot...lastSlot).map { candleBySlot[$0] }
    }

    private static func lastVisibleSlot(
        firstSlot: Int,
        candles: [IntradayCandle],
        interval: IntradayInterval,
        displayMode: IntradayChartDisplayMode,
    ) -> Int {
        let fullDayLastSlot = firstSlot + interval.slotsPerDay - 1
        guard displayMode == .elapsedDay,
              let latestCandleSlot = candles.map({ slotIndex(for: $0.openTime, interval: interval) }).max() else {
            return fullDayLastSlot
        }
        return min(max(firstSlot, latestCandleSlot), fullDayLastSlot)
    }

    private static func slotIndex(for date: Date, interval: IntradayInterval) -> Int {
        Int(floor(date.timeIntervalSince1970 / interval.seconds))
    }

    private func double(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}

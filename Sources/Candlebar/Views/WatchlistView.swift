import SwiftUI

private enum WatchlistLayout {
    static let rowHeight: CGFloat = 62
    static let rowSpacing: CGFloat = 6
    static let maxVisibleRows = 5

    static func height(for count: Int) -> CGFloat {
        let visibleRows = min(max(count, 1), maxVisibleRows)
        return CGFloat(visibleRows) * rowHeight + CGFloat(visibleRows - 1) * rowSpacing
    }
}

struct WatchlistView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        let watchlistCount = store.preferences.watchlist.count

        PixelCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(LocalizedCopy.text(.watchlist, language: store.preferences.language))
                        .font(PixelFont.section)
                        .foregroundStyle(PixelColors.accent)
                    Spacer()
                    Text("\(store.preferences.watchlist.count)/30")
                        .font(PixelFont.tiny)
                        .foregroundStyle(store.preferences.watchlist.count >= AppStore.watchlistLimit ? PixelColors.warn : PixelColors.muted)
                }

                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(store.preferences.watchlist) { item in
                            TickerRow(
                                item: item,
                                ticker: store.tickers[item.cacheKey],
                                isDefault: item.id == store.defaultItem.id,
                            ) {
                                store.setDefault(item)
                            }
                        }
                    }
                }
                .scrollIndicators(watchlistCount > WatchlistLayout.maxVisibleRows ? .visible : .hidden)
                .frame(height: WatchlistLayout.height(for: watchlistCount))
            }
        }
        .layoutPriority(1)
    }
}

struct TickerRow: View {
    @EnvironmentObject private var store: AppStore
    var item: WatchSymbol
    var ticker: TickerSnapshot?
    var isDefault: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(isDefault ? ">" : " ")
                    .font(PixelFont.section)
                    .foregroundStyle(PixelColors.accent)
                    .frame(width: 10)

                if store.preferences.pixelTheme {
                    PixelGlyph(kind: glyphKind(for: ticker?.movement ?? .flat, fallback: ticker?.status))
                        .help(ticker?.status.rawValue.uppercased() ?? "IDLE")
                }

                HStack(alignment: .center, spacing: 10) {
                    Text(item.symbol)
                        .font(.system(size: 17, weight: .black, design: .monospaced))
                        .foregroundStyle(PixelColors.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .layoutPriority(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        PixelBadge(text: item.market.shortName, color: isDefault ? PixelColors.accent : PixelColors.cyan)
                            .fixedSize()
                        Text(statusText)
                            .font(PixelFont.tiny)
                            .foregroundStyle(PixelColors.muted)
                            .lineLimit(1)
                            .frame(width: 58, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(CandleFormat.price(ticker?.lastPrice, decimalPlaces: store.preferences.priceDecimalPlaces))
                        .font(PixelFont.number)
                        .foregroundStyle(PixelColors.text)
                        .lineLimit(1)
                    Text(CandleFormat.percent(ticker?.priceChangePercent))
                        .font(PixelFont.tiny)
                        .foregroundStyle((ticker?.isPositive ?? true) ? PixelColors.up : PixelColors.down)
                }
                .frame(width: 108, alignment: .trailing)
            }
            .padding(.horizontal, 8)
            .frame(height: WatchlistLayout.rowHeight)
            .background(isDefault ? PixelColors.raisedAlt : PixelColors.background)
            .pixelFlash(store.preferences.pixelTheme ? ticker?.movement ?? .flat : .flat)
            .overlay(Rectangle().stroke(isDefault ? PixelColors.accent : PixelColors.line.opacity(0.75), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("Set \(item.symbol) as menu bar symbol")
    }

    private var statusText: String {
        ticker?.message ?? CandleFormat.relativeTime(ticker?.updatedAt)
    }
}

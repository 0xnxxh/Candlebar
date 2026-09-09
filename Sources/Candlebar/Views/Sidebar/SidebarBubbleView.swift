import SwiftUI

struct SidebarBubbleView: View {
    @EnvironmentObject private var store: AppStore
    var item: SidebarItem
    var onOpenMainPanel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
            footer
        }
        .padding(14)
        .background(PixelColors.raised)
        .overlay(
            Rectangle()
                .strokeBorder(accent, lineWidth: 1),
        )
        .foregroundStyle(PixelColors.text)
        .fixedSize()
    }

    /// Border tint, matching the ring the bubble was opened from.
    private var accent: Color {
        switch item {
        case let .symbol(symbol): intradayColor(store.watchlistIntradayPercent(for: symbol))
        case .account: intradayColor(store.accountOverview.usdtChangePercent)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch item {
        case let .symbol(symbol):
            symbolContent(symbol)
        case .account:
            accountContent
        }
    }

    private func symbolContent(_ symbol: WatchSymbol) -> some View {
        let ticker = store.tickers[symbol.cacheKey]
        let percent = store.watchlistIntradayPercent(for: symbol)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(symbol.symbol)
                    .font(PixelFont.title)
                PixelBadge(text: symbol.market.shortName, color: PixelColors.cyan)
                Spacer()
                PixelBadge(text: ticker?.status.rawValue ?? "idle", color: statusColor(ticker?.status))
            }

            HStack(alignment: .center, spacing: 10) {
                Text(CandleFormat.price(ticker?.lastPrice, decimalPlaces: store.preferences.priceDecimalPlaces))
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Spacer(minLength: 0)

                Text(CandleFormat.percent(percent))
                    .font(PixelFont.number)
                    .foregroundStyle(intradayColor(percent))
            }

            IntradayCandlestickView(
                series: store.watchlistIntradaySeries[symbol.cacheKey],
                currentPrice: ticker?.lastPrice,
                displayMode: store.preferences.headerChartDisplayMode,
                tint: intradayColor(percent),
            )
            .frame(height: 72)

            Text("\(LocalizedCopy.text(.updated, language: store.preferences.language)) \(CandleFormat.relativeTime(ticker?.updatedAt))")
                .font(PixelFont.tiny)
                .foregroundStyle(PixelColors.muted)
        }
        .frame(width: SidebarLayout.symbolContentWidth, alignment: .leading)
    }

    private var accountContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(LocalizedCopy.text(.account, language: store.preferences.language))
                    .font(PixelFont.section)
                    .foregroundStyle(PixelColors.accent)
                Spacer()
                PixelBadge(
                    text: LocalizedCopy.accountStatusText(store.accountOverview.statusText, language: store.preferences.language),
                    color: statusColor(store.accountOverview.status),
                )
            }

            if store.apiKeyState.hasKey {
                AccountSummaryView(
                    overview: store.accountOverview,
                    hideBalances: store.preferences.hideBalances,
                    hideLowValueAccounts: store.preferences.hideLowValueAccounts,
                    language: store.preferences.language,
                    decimalPlaces: store.preferences.priceDecimalPlaces,
                )
            } else {
                MissingKeyView(language: store.preferences.language)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button(LocalizedCopy.text(.openMainPanel, language: store.preferences.language)) {
                onOpenMainPanel()
            }
            .buttonStyle(PixelButtonStyle(tint: PixelColors.cyan))

            Spacer()

            Button {
                Task { await store.refreshAll() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(PixelButtonStyle())
            .help(LocalizedCopy.text(.refresh, language: store.preferences.language))
        }
    }
}

import SwiftUI

enum SidebarItem: Identifiable, Equatable {
    case symbol(WatchSymbol)
    case account

    var id: String {
        switch self {
        case let .symbol(item): item.id.uuidString
        case .account: "account"
        }
    }
}

extension AppStore {
    /// Watchlist entries followed by the account summary, in rail order.
    func sidebarItems(for preferences: AppPreferences) -> [SidebarItem] {
        let symbols = preferences.watchlist.map(SidebarItem.symbol)
        return preferences.showAccountRing ? symbols + [.account] : symbols
    }

    var sidebarItems: [SidebarItem] {
        sidebarItems(for: preferences)
    }
}

struct SidebarRailView: View {
    @EnvironmentObject private var store: AppStore
    var selectedItemID: String?
    var onSelect: (SidebarItem, Int) -> Void
    var onDragChanged: () -> Void
    var onDragEnded: () -> Void

    var body: some View {
        VStack(spacing: SidebarLayout.itemSpacing) {
            ForEach(Array(store.sidebarItems.enumerated()), id: \.element.id) { index, item in
                Button {
                    onSelect(item, index)
                } label: {
                    cell(for: item)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, SidebarLayout.railVerticalPadding)
        .padding(.horizontal, SidebarLayout.horizontalPadding)
        .frame(width: SidebarLayout.railWidth, alignment: .top)
        .background(PixelColors.raised)
        .overlay(
            Rectangle()
                .strokeBorder(PixelColors.line, lineWidth: 1),
        )
        // Simultaneous so a press still reaches the item buttons; the minimum
        // distance keeps a plain click from being read as a drag.
        .simultaneousGesture(
            DragGesture(minimumDistance: 6)
                .onChanged { _ in
                    onDragChanged()
                }
                .onEnded { _ in
                    onDragEnded()
                },
        )
    }

    private func cell(for item: SidebarItem) -> some View {
        let percent = percent(for: item)
        let isSelected = selectedItemID == item.id
        let tint = intradayColor(percent)

        return VStack(alignment: .leading, spacing: SidebarLayout.rowLineSpacing) {
            HStack(spacing: 4) {
                Text(shortLabel(for: item))
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(isSelected ? PixelColors.accent : PixelColors.text)
                    .lineLimit(1)
                Spacer(minLength: 2)
                PixelSparkline(values: sparklineValues(for: item), tint: tint)
            }

            Text(priceText(for: item))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(PixelColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            HStack(spacing: 4) {
                Text(CandleFormat.percent(percent))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 2)
                Text(marketText(for: item))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PixelColors.muted)
            }
        }
        .frame(width: SidebarLayout.itemWidth, height: SidebarLayout.itemHeight, alignment: .leading)
        .background(isSelected ? PixelColors.raisedAlt : Color.clear)
        .contentShape(Rectangle())
        .help(helpText(for: item))
    }

    /// Account value follows the same masking as the rest of the app; a rail
    /// that leaked balances would defeat `hideBalances`.
    private func priceText(for item: SidebarItem) -> String {
        switch item {
        case let .symbol(symbol):
            CandleFormat.price(
                store.tickers[symbol.cacheKey]?.lastPrice,
                decimalPlaces: store.preferences.priceDecimalPlaces,
            )
        case .account:
            store.preferences.hideBalances
                ? "****"
                : CandleFormat.compactPrice(store.accountOverview.usdEstimatedValue)
        }
    }

    private func marketText(for item: SidebarItem) -> String {
        switch item {
        case let .symbol(symbol): symbol.market.shortName
        case .account: "USD"
        }
    }

    private func sparklineValues(for item: SidebarItem) -> [Decimal] {
        switch item {
        case let .symbol(symbol):
            store.watchlistIntradaySeries[symbol.cacheKey]?.candles.map(\.close) ?? []
        // The account has no intraday series to plot; the row shows a flat track.
        case .account:
            []
        }
    }

    private func percent(for item: SidebarItem) -> Decimal? {
        switch item {
        case let .symbol(symbol): store.watchlistIntradayPercent(for: symbol)
        case .account: store.accountOverview.usdEstimatedChangePercentToday
        }
    }

    private func shortLabel(for item: SidebarItem) -> String {
        switch item {
        case let .symbol(symbol): String(symbol.symbol.replacingOccurrences(of: "USDT", with: "").prefix(6)).uppercased()
        case .account: "ACC"
        }
    }

    private func helpText(for item: SidebarItem) -> String {
        switch item {
        case let .symbol(symbol): "\(symbol.symbol) · \(symbol.market.shortName)"
        case .account: LocalizedCopy.text(.sidebarAccount, language: store.preferences.language)
        }
    }
}

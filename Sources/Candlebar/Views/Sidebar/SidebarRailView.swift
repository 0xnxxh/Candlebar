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

        return VStack(spacing: SidebarLayout.labelSpacing) {
            RingGauge(
                fraction: SidebarLayout.ringFraction(percent: percent),
                tint: intradayColor(percent),
                label: shortLabel(for: item),
                isHighlighted: isSelected,
            )
            Text(CandleFormat.percent(percent))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(intradayColor(percent))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(height: SidebarLayout.labelHeight)
        }
        .frame(width: SidebarLayout.itemWidth, height: SidebarLayout.itemHeight)
        .background(isSelected ? PixelColors.raisedAlt : Color.clear)
        .contentShape(Rectangle())
        .help(helpText(for: item))
    }

    private func percent(for item: SidebarItem) -> Decimal? {
        switch item {
        case let .symbol(symbol): store.watchlistIntradayPercent(for: symbol)
        case .account: store.accountOverview.usdEstimatedChangePercentToday
        }
    }

    private func shortLabel(for item: SidebarItem) -> String {
        switch item {
        case let .symbol(symbol): symbol.symbol.replacingOccurrences(of: "USDT", with: "").prefix(4).uppercased()
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

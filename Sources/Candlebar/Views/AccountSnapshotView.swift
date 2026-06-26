import SwiftUI

struct AccountSnapshotView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var isExpanded: Bool

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack {
                        Text(isExpanded ? "v" : ">")
                            .font(PixelFont.section)
                            .foregroundStyle(PixelColors.accent)
                            .frame(width: 10)
                        Text(LocalizedCopy.text(.account, language: store.preferences.language))
                            .font(PixelFont.section)
                            .foregroundStyle(PixelColors.accent)
                        Spacer()
                        PixelBadge(
                            text: LocalizedCopy.accountStatusText(store.accountOverview.statusText, language: store.preferences.language),
                            color: statusColor(store.accountOverview.status),
                        )
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(LocalizedCopy.text(
                    isExpanded ? .accountDetailsCollapse : .accountDetailsExpand,
                    language: store.preferences.language,
                ))

                if store.apiKeyState.hasKey {
                    AccountSummaryView(
                        overview: store.accountOverview,
                        hideBalances: store.preferences.hideBalances,
                        hideLowValueAccounts: store.preferences.hideLowValueAccounts,
                        language: store.preferences.language,
                        decimalPlaces: store.preferences.priceDecimalPlaces,
                    )

                    if isExpanded {
                        AccountDetailsView(
                            overview: store.accountOverview,
                            hideBalances: store.preferences.hideBalances,
                            language: store.preferences.language,
                            decimalPlaces: store.preferences.priceDecimalPlaces,
                        )
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                } else {
                    MissingKeyView(language: store.preferences.language)
                }
            }
        }
        .animation(nil, value: isExpanded)
    }
}

private struct AccountSummaryView: View {
    var overview: AccountOverview
    var hideBalances: Bool
    var hideLowValueAccounts: Bool
    var language: AppLanguage
    var decimalPlaces: Int

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows) { row in
                AccountSummaryRow(row: row, hideBalances: hideBalances)
            }
        }
    }

    private var rows: [AccountSummaryMetric] {
        [
            AccountSummaryMetric(
                title: LocalizedCopy.text(.summaryTotal, language: language),
                value: overview.usdEstimatedValue,
                change: overview.usdEstimatedChangeToday,
                unavailableChangeText: missingTodayText,
                shouldHideWhenLowValue: false,
                help: "Total = spot stablecoin estimate plus USD-M wallet balance. Today change uses Binance daily account snapshot as the UTC+0 day baseline when available. COIN-M is not mixed into this USD estimate.",
            ),
            AccountSummaryMetric(
                title: LocalizedCopy.text(.summarySpot, language: language),
                value: overview.spotEstimatedValue ?? 0,
                change: 0,
                unavailableChangeText: nil,
                shouldHideWhenLowValue: true,
                help: "Spot value is free plus locked stablecoin balances only. Spot PnL is unavailable without cost basis, so change is shown as +0 USDT.",
            ),
            AccountSummaryMetric(
                title: LocalizedCopy.text(.summaryUsdM, language: language),
                value: overview.usdMWalletBalance,
                change: overview.usdMUnrealizedPnL,
                unavailableChangeText: nil,
                shouldHideWhenLowValue: true,
                help: "USD-M wallet balance and unrealized PnL from Binance futures account data.",
            ),
            AccountSummaryMetric(
                title: LocalizedCopy.text(.summaryCoinM, language: language),
                value: overview.coinMWalletBalance ?? 0,
                change: overview.coinMUnrealizedPnL ?? 0,
                unavailableChangeText: nil,
                shouldHideWhenLowValue: true,
                help: "COIN-M wallet balance and unrealized PnL are shown separately because coin-margined balances are not added to Total.",
            ),
        ].filter { metric in
            !hideLowValueAccounts || !metric.shouldHideWhenLowValue || metric.valueMagnitude >= 1
        }
    }

    private var missingTodayText: String {
        switch language {
        case .english: "DAY N/A"
        case .chinese: "今日无基线"
        }
    }
}

private struct AccountSummaryMetric: Identifiable {
    let id = UUID()
    var title: String
    var value: Decimal?
    var change: Decimal?
    var unavailableChangeText: String?
    var shouldHideWhenLowValue: Bool
    var help: String

    var valueMagnitude: Decimal {
        (value ?? 0).magnitude
    }
}

private struct AccountSummaryRow: View {
    var row: AccountSummaryMetric
    var hideBalances: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(row.title)
                .font(PixelFont.tiny)
                .foregroundStyle(PixelColors.muted)
                .frame(width: 64, alignment: .leading)

            Spacer(minLength: 0)

            Text(display(valueText))
                .font(PixelFont.tiny)
                .foregroundStyle(PixelColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 110, alignment: .trailing)

            Text("/")
                .font(PixelFont.tiny)
                .foregroundStyle(PixelColors.muted)
                .frame(width: 10, alignment: .center)

            Text(display(changeText))
                .font(PixelFont.tiny)
                .foregroundStyle(signedColor(for: changeText))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 110, alignment: .trailing)
        }
        .help(row.help)
    }

    private var valueText: String {
        guard let value = row.value else {
            return "--"
        }
        return "\(CandleFormat.price(value, decimalPlaces: 2)) USDT"
    }

    private var changeText: String {
        guard let change = row.change else {
            return row.unavailableChangeText ?? "--"
        }
        return "\(CandleFormat.signedMoney(change)) USDT"
    }

    private func display(_ value: String) -> String {
        hideBalances ? "****" : value
    }
}

private struct AccountDetailsView: View {
    var overview: AccountOverview
    var hideBalances: Bool
    var language: AppLanguage
    var decimalPlaces: Int

    var body: some View {
        VStack(spacing: 8) {
            if let message = overview.message, !message.isEmpty {
                Text(message)
                    .font(PixelFont.tiny)
                    .foregroundStyle(PixelColors.warn)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if overview.positions.isEmpty {
                HStack {
                    Text(LocalizedCopy.text(.positions, language: language))
                    Spacer()
                    Text(LocalizedCopy.text(.noneOrNotLoaded, language: language))
                }
                .font(PixelFont.tiny)
                .foregroundStyle(PixelColors.muted)
            } else {
                ForEach(overview.positions) { position in
                    PositionRow(position: position, language: language, decimalPlaces: decimalPlaces)
                }
            }
        }
    }

}

private struct PositionRow: View {
    var position: FuturesPosition
    var language: AppLanguage
    var decimalPlaces: Int

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                HStack(spacing: 6) {
                    Text(position.symbol)
                        .foregroundStyle(PixelColors.text)
                    Text(positionSideText)
                        .foregroundStyle(position.isLong ? PixelColors.up : PixelColors.down)
                }
                Spacer()
                Text("\(LocalizedCopy.text(.positionLeverage, language: language)) \(position.displayLeverage)")
                    .foregroundStyle(PixelColors.warn)
            }
            HStack {
                Text("\(LocalizedCopy.text(.positionSize, language: language)) \(price(position.quantity))")
                Spacer()
                Text("\(LocalizedCopy.text(.positionUnrealizedPnL, language: language)) \(CandleFormat.signedMoney(position.unrealizedPnL))")
                    .foregroundStyle((position.unrealizedPnL ?? 0) >= 0 ? PixelColors.up : PixelColors.down)
            }
            HStack {
                Text("\(LocalizedCopy.text(.positionEntry, language: language)) \(price(position.entryPrice))")
                Spacer()
                Text("\(LocalizedCopy.text(.positionMark, language: language)) \(price(position.markPrice))")
            }
            HStack {
                Text("\(LocalizedCopy.text(.positionBreakeven, language: language)) \(price(position.breakevenPrice))")
                Spacer()
                Text("\(LocalizedCopy.text(.positionLiquidation, language: language)) \(price(position.liquidationPrice))")
            }
            HStack {
                Text(LocalizedCopy.text(.positionRatio, language: language))
                Spacer()
                Text(CandleFormat.percent(position.pnlRatio))
            }
            .foregroundStyle(PixelColors.muted)
            .help("PnL ratio = unrealized PnL / absolute entry notional. It is not margin ROI.")
        }
        .font(PixelFont.tiny)
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .overlay(Rectangle().stroke(PixelColors.line, lineWidth: 1))
    }

    private func price(_ value: Decimal?) -> String {
        CandleFormat.price(value, decimalPlaces: decimalPlaces)
    }

    private var positionSideText: String {
        switch language {
        case .english:
            position.isLong ? "LONG" : "SHORT"
        case .chinese:
            position.isLong ? "多" : "空"
        }
    }
}

private struct MissingKeyView: View {
    var language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedCopy.text(.noKeyCopy, language: language))
                .font(PixelFont.body)
                .foregroundStyle(PixelColors.text)
            Text(LocalizedCopy.text(.noKeyRiskCopy, language: language))
                .font(PixelFont.tiny)
                .foregroundStyle(PixelColors.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private func signedColor(for value: String) -> Color {
    if value.hasPrefix("+") { return PixelColors.up }
    if value.hasPrefix("-") { return PixelColors.down }
    return PixelColors.text
}

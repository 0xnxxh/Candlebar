import AppKit
import SwiftUI

enum MainPanelLayout {
    static let width: CGFloat = 400
    static let expandedFallbackScrollHeight: CGFloat = 520
    static let menuBarGap: CGFloat = 6
    static let screenEdgeInset: CGFloat = 8
    private static let nonScrollableExpandedHeight: CGFloat = 80
    static let collapsedSize = CGSize(width: width, height: 590)

    static var expandedContentMaxHeight: CGFloat {
        let visibleHeight = NSScreen.main?.visibleFrame.height ?? 560
        return max(220, visibleHeight - nonScrollableExpandedHeight)
    }

    static func size(isExpanded: Bool) -> CGSize {
        guard isExpanded else { return collapsedSize }
        let height = expandedContentMaxHeight + nonScrollableExpandedHeight
        return CGSize(
            width: width,
            height: min(height, NSScreen.main?.visibleFrame.height ?? height),
        )
    }
}

struct MainPanelView: View {
    @EnvironmentObject private var store: AppStore
    var onExpandedChange: ((Bool) -> Void)?
    @State private var isAccountExpanded = false

    var body: some View {
        panelBody
            .id(isAccountExpanded ? "expanded-panel" : "collapsed-panel")
            .background(PixelColors.background)
            .foregroundStyle(PixelColors.text)
            .onChange(of: isAccountExpanded) { _, value in
                onExpandedChange?(value)
            }
            .task {
                await store.refreshAll()
            }
    }

    private var panelBody: some View {
        VStack(spacing: 10) {
            ScrollView {
                panelContent
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollDisabled(!isAccountExpanded)
            .scrollIndicators(.hidden)
            .frame(maxHeight: isAccountExpanded ? MainPanelLayout.expandedContentMaxHeight : nil)

            StatusFooterView()
                .layoutPriority(3)
        }
        .padding(12)
        .frame(width: MainPanelLayout.width, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var panelContent: some View {
        VStack(spacing: 10) {
            HeaderView()
                .layoutPriority(3)

            WatchlistView()
                .layoutPriority(2)

            AccountSnapshotView(isExpanded: $isAccountExpanded)
                .layoutPriority(isAccountExpanded ? 3 : 1)
        }
    }
}

private struct HeaderView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        let item = store.defaultItem
        let ticker = store.defaultTicker
        let intraday = store.defaultIntradaySeries
        let intradayPercent = store.intradayPercent(for: item)

        PixelCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            if store.preferences.pixelTheme {
                                PixelGlyph(kind: glyphKind(for: ticker?.movement ?? .flat, fallback: ticker?.status), size: 4)
                                    .help("Price/status pixel indicator")
                            }
                            PixelBadge(text: item.market.shortName, color: PixelColors.accent)
                            PixelBadge(text: ticker?.status.rawValue ?? "idle", color: statusColor(ticker?.status))
                        }
                        Text(item.symbol)
                            .font(PixelFont.title)
                            .foregroundStyle(PixelColors.text)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Button {
                            store.updatePinMainPanel(!store.preferences.pinMainPanel)
                        } label: {
                            Image(systemName: store.preferences.pinMainPanel ? "pin.fill" : "pin.slash")
                        }
                        .buttonStyle(PixelButtonStyle(tint: store.preferences.pinMainPanel ? PixelColors.up : PixelColors.muted))
                        .help(
                            LocalizedCopy.text(
                                store.preferences.pinMainPanel ? .pinMainPanel : .pinMainPanelOff,
                                language: store.preferences.language,
                            ),
                        )

                        Button {
                            Task { await store.refreshAll() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(PixelButtonStyle())
                        .help(LocalizedCopy.text(.refresh, language: store.preferences.language))
                    }
                }

                HStack(alignment: .center, spacing: 10) {
                    Text(CandleFormat.price(ticker?.lastPrice, decimalPlaces: store.preferences.priceDecimalPlaces))
                        .font(.system(size: 30, weight: .black, design: .monospaced))
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                        .padding(.horizontal, 3)
                        .pixelFlash(store.preferences.pixelTheme ? ticker?.movement ?? .flat : .flat)
                        .frame(maxWidth: 120, alignment: .leading)

                    Spacer()

                    IntradayCandlestickView(
                        series: intraday,
                        currentPrice: ticker?.lastPrice,
                        tint: intradayColor(intradayPercent),
                    )
                    .frame(width: 138, height: 72)

                    Spacer()

                    Text(CandleFormat.percent(intradayPercent))
                        .font(PixelFont.number)
                        .foregroundStyle(intradayColor(intradayPercent))
                        .frame(width: 68, alignment: .trailing)
                }

                HStack {
                    Text("\(LocalizedCopy.text(.updated, language: store.preferences.language)) \(CandleFormat.relativeTime(ticker?.updatedAt))")
                        .font(PixelFont.tiny)
                        .foregroundStyle(PixelColors.muted)

                    Spacer()

                    PixelProgress(
                        active: store.isRefreshing,
                        filledCount: tickerFreshnessSegments(ticker),
                        tint: statusColor(ticker?.status),
                    )
                    .help("Ticker freshness")
                }
            }
        }
    }
}

func intradayColor(_ percent: Decimal?) -> Color {
    guard let percent else {
        return PixelColors.muted
    }
    return percent >= 0 ? PixelColors.up : PixelColors.down
}

private func tickerFreshnessSegments(_ ticker: TickerSnapshot?) -> Int {
    guard let updatedAt = ticker?.updatedAt else {
        return 0
    }
    let age = max(0, Date().timeIntervalSince(updatedAt))
    if age < 5 { return 12 }
    if age < 10 { return 9 }
    if age < 30 { return 5 }
    return 2
}

private struct StatusFooterView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        HStack(spacing: 8) {
            PixelBadge(
                text: LocalizedCopy.apiKeyStatusText(store.apiKeyState.statusText, language: store.preferences.language),
                color: store.apiKeyState.hasKey ? PixelColors.warn : PixelColors.down,
            )

            Spacer()

            Button {
                SettingsOpener.open(store: store)
            } label: {
                Label(LocalizedCopy.text(.settings, language: store.preferences.language), systemImage: "gearshape")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(PixelButtonStyle(tint: PixelColors.cyan))

            Button(LocalizedCopy.text(.quit, language: store.preferences.language)) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(PixelButtonStyle(tint: PixelColors.down))
        }
    }
}

func statusColor(_ status: FeedStatus?) -> Color {
    switch status {
    case .live: PixelColors.up
    case .warning, .stale: PixelColors.warn
    case .offline, .error: PixelColors.down
    case .idle, .loading, .none: PixelColors.cyan
    }
}

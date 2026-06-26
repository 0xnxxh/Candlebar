import Sparkle
import SwiftUI

struct SettingsWatchlistTab: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            addSymbolCard
            currentWatchlistCard
        }
    }

    private var addSymbolCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    PixelField(
                        placeholder: LocalizedCopy.text(.searchPlaceholder, language: store.preferences.language),
                        text: Binding(
                            get: { store.newSymbolDraft },
                            set: store.updateNewSymbolDraft,
                        ),
                    )

                    PixelMarketSelector(selection: Binding(
                        get: { store.newMarketDraft },
                        set: store.updateNewMarketDraft,
                    ))

                    Button(LocalizedCopy.text(.add, language: store.preferences.language)) {
                        store.addDraftSymbol()
                    }
                    .buttonStyle(PixelButtonStyle())
                    .disabled(store.preferences.watchlist.count >= AppStore.watchlistLimit)
                }

                if store.preferences.watchlist.count >= AppStore.watchlistLimit {
                    Text("\(LocalizedCopy.text(.watchlistLimit, language: store.preferences.language)) \(AppStore.watchlistLimit)")
                        .font(PixelFont.tiny)
                        .foregroundStyle(PixelColors.warn)
                }

                SearchResultsView()
            }
        }
    }

    private var currentWatchlistCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(LocalizedCopy.text(.current, language: store.preferences.language))
                        .font(PixelFont.section)
                        .foregroundStyle(PixelColors.accent)
                    Spacer()
                    Text("\(store.preferences.watchlist.count)/\(AppStore.watchlistLimit)")
                        .font(PixelFont.tiny)
                        .foregroundStyle(PixelColors.muted)
                }

                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(Array(store.preferences.watchlist.enumerated()), id: \.element.id) { index, item in
                            SettingsWatchlistRow(item: item, index: index)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .frame(maxHeight: 220)
            }
        }
    }
}

struct SettingsAPIKeysTab: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: 12) {
                SettingsCopyBlock(
                    title: LocalizedCopy.text(.readOnlyKey, language: store.preferences.language),
                    message: LocalizedCopy.text(.readOnlyKeyCopy, language: store.preferences.language),
                )

                PixelSecureField(placeholder: "API Key", text: $store.apiKeyDraft)
                PixelSecureField(placeholder: "API Secret", text: $store.apiSecretDraft)

                HStack {
                    Button(LocalizedCopy.text(.saveAndTest, language: store.preferences.language)) {
                        store.saveDraftAPIKey()
                    }
                    .buttonStyle(PixelButtonStyle())

                    Button(LocalizedCopy.text(.deleteKey, language: store.preferences.language)) {
                        store.deleteAPIKey()
                    }
                    .buttonStyle(PixelButtonStyle(tint: PixelColors.down))

                    Spacer()

                    PixelBadge(
                        text: store.apiKeyState.statusText,
                        color: store.apiKeyState.hasKey ? PixelColors.warn : PixelColors.down,
                    )
                }
            }
        }
    }
}

struct SettingsAppearanceTab: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        PixelCard {
            VStack(spacing: 10) {
                ToggleRow(
                    title: LocalizedCopy.text(.pixelTheme, language: store.preferences.language),
                    isOn: Binding(
                        get: { store.preferences.pixelTheme },
                        set: store.updatePixelTheme,
                    ),
                )
                ToggleRow(
                    title: LocalizedCopy.text(.compactMenuBar, language: store.preferences.language),
                    isOn: Binding(
                        get: { store.preferences.compactMenuBar },
                        set: store.updateCompactMenuBar,
                    ),
                )
                ToggleRow(
                    title: LocalizedCopy.text(.hideBalances, language: store.preferences.language),
                    isOn: Binding(
                        get: { store.preferences.hideBalances },
                        set: store.updateHideBalances,
                    ),
                )
                ToggleRow(
                    title: LocalizedCopy.text(.hideLowValueAccount, language: store.preferences.language),
                    isOn: Binding(
                        get: { store.preferences.hideLowValueAccounts },
                        set: store.updateHideLowValueAccounts,
                    ),
                )
                languageRow
                decimalsRow
            }
        }
    }

    private var languageRow: some View {
        HStack {
            Text(LocalizedCopy.text(.language, language: store.preferences.language))
                .font(PixelFont.section)
                .foregroundStyle(PixelColors.muted)
            Spacer()
            PixelLanguageSelector(selection: Binding(
                get: { store.preferences.language },
                set: store.updateLanguage,
            ))
        }
        .padding(.vertical, 6)
    }

    private var decimalsRow: some View {
        HStack {
            Text(LocalizedCopy.text(.priceDecimals, language: store.preferences.language))
                .font(PixelFont.section)
                .foregroundStyle(PixelColors.muted)
            Spacer()
            PixelStepper(
                value: store.preferences.priceDecimalPlaces,
                range: 0...8,
            ) { value in
                store.updatePriceDecimalPlaces(Double(value))
            }
        }
        .padding(.vertical, 6)
    }
}

struct SettingsDiagnosticsTab: View {
    @EnvironmentObject private var store: AppStore
    var updater: SPUUpdater?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PixelCard {
                VStack(spacing: 8) {
                    diagnosticRow(LocalizedCopy.text(.tickerRefresh, language: store.preferences.language), store.isRefreshing ? "RUNNING" : "IDLE")
                    diagnosticRow(LocalizedCopy.text(.defaultSymbol, language: store.preferences.language), store.defaultItem.symbol)
                    diagnosticRow(LocalizedCopy.text(.apiKey, language: store.preferences.language), store.apiKeyState.statusText)
                    diagnosticRow(LocalizedCopy.text(.account, language: store.preferences.language), store.accountOverview.statusText)
                    diagnosticRow(LocalizedCopy.text(.lastError, language: store.preferences.language), store.lastError ?? LocalizedCopy.text(.none, language: store.preferences.language))
                }
            }

            HStack {
                if let updater {
                    CheckForUpdatesView(updater: updater, language: store.preferences.language)
                }

                Button(LocalizedCopy.text(.exportDiagnostics, language: store.preferences.language)) {
                    store.exportDiagnostics()
                }
                .buttonStyle(PixelButtonStyle())
            }

            if let diagnosticExport = store.diagnosticExport {
                PixelCard {
                    ScrollView {
                        Text(diagnosticExport)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(PixelColors.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(minHeight: 160)
                    .scrollIndicators(.hidden)
                }
            }
        }
    }

    private func diagnosticRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(PixelFont.tiny)
                .foregroundStyle(PixelColors.muted)
            Spacer()
            Text(value)
                .font(PixelFont.tiny)
                .foregroundStyle(PixelColors.text)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

private struct SearchResultsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        if store.isLoadingSymbols {
            PixelProgress(active: true)
        } else if !store.symbolSearchResults.isEmpty {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(store.symbolSearchResults) { result in
                        Button {
                            store.addSearchResult(result)
                        } label: {
                            HStack {
                                PixelBadge(text: result.market.shortName, color: PixelColors.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.symbol)
                                        .font(PixelFont.section)
                                        .foregroundStyle(PixelColors.text)
                                    Text(result.pairText)
                                        .font(PixelFont.tiny)
                                        .foregroundStyle(PixelColors.muted)
                                }
                                Spacer()
                                Image(systemName: "plus")
                                    .foregroundStyle(PixelColors.up)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 180)
            .background(PixelColors.background)
            .overlay(Rectangle().stroke(PixelColors.line.opacity(0.6), lineWidth: 1))
        }
    }
}

private struct SettingsWatchlistRow: View {
    @EnvironmentObject private var store: AppStore
    var item: WatchSymbol
    var index: Int

    var body: some View {
        HStack(spacing: 8) {
            PixelBadge(text: item.market.shortName, color: item.id == store.defaultItem.id ? PixelColors.accent : PixelColors.cyan)
                .frame(width: 58, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.symbol)
                    .font(PixelFont.section)
                    .foregroundStyle(PixelColors.text)
                    .lineLimit(1)
                Text(item.id == store.defaultItem.id
                    ? LocalizedCopy.text(.defaultRow, language: store.preferences.language)
                    : LocalizedCopy.text(.watching, language: store.preferences.language))
                    .font(PixelFont.tiny)
                    .foregroundStyle(item.id == store.defaultItem.id ? PixelColors.accent : PixelColors.muted)
            }

            Spacer()

            Button {
                store.setDefault(item)
            } label: {
                Image(systemName: "star")
            }
            .buttonStyle(PixelIconButtonStyle(tint: PixelColors.accent))
            .help(LocalizedCopy.text(.setDefault, language: store.preferences.language))

            Button {
                store.moveSymbols(from: IndexSet(integer: index), to: max(index - 1, 0))
            } label: {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(PixelIconButtonStyle(tint: PixelColors.cyan))
            .disabled(index == 0)
            .help(LocalizedCopy.text(.moveUp, language: store.preferences.language))

            Button {
                store.moveSymbols(from: IndexSet(integer: index), to: min(index + 2, store.preferences.watchlist.count))
            } label: {
                Image(systemName: "arrow.down")
            }
            .buttonStyle(PixelIconButtonStyle(tint: PixelColors.cyan))
            .disabled(index >= store.preferences.watchlist.count - 1)
            .help(LocalizedCopy.text(.moveDown, language: store.preferences.language))

            Button {
                store.removeSymbols(at: IndexSet(integer: index))
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(PixelIconButtonStyle(tint: PixelColors.down))
            .help(LocalizedCopy.text(.remove, language: store.preferences.language))
        }
        .padding(.horizontal, 8)
        .frame(height: 44)
        .background(PixelColors.background)
        .overlay(Rectangle().stroke(PixelColors.line.opacity(0.65), lineWidth: 1))
    }
}

private struct SettingsCopyBlock: View {
    var title: String
    var message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(PixelFont.section)
                .foregroundStyle(PixelColors.accent)
            Text(message)
                .font(PixelFont.tiny)
                .foregroundStyle(PixelColors.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

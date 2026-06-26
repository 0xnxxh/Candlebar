import Sparkle
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    var updater: SPUUpdater?
    @State private var selectedTab: SettingsTab = .watchlist

    var body: some View {
        HStack(spacing: 0) {
            tabRail

            Divider()
                .overlay(PixelColors.line)

            VStack(alignment: .leading, spacing: 12) {
                Text(selectedTab.title(language: store.preferences.language))
                    .font(PixelFont.section)
                    .foregroundStyle(PixelColors.accent)

                ScrollView {
                    selectedTabContent
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .scrollIndicators(.visible)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 620, height: 460)
        .background(PixelColors.background)
        .foregroundStyle(PixelColors.text)
    }

    private var tabRail: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .frame(width: 18)
                        Text(tab.title(language: store.preferences.language))
                            .lineLimit(1)
                        Spacer()
                    }
                    .font(PixelFont.section)
                    .foregroundStyle(selectedTab == tab ? PixelColors.background : PixelColors.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(selectedTab == tab ? PixelColors.accent : PixelColors.raised)
                    .overlay(Rectangle().stroke(selectedTab == tab ? PixelColors.accent : PixelColors.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(12)
        .frame(width: 156)
        .background(PixelColors.raised)
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case .watchlist:
            SettingsWatchlistTab()
        case .apiKeys:
            SettingsAPIKeysTab()
        case .appearance:
            SettingsAppearanceTab()
        case .diagnostics:
            SettingsDiagnosticsTab(updater: updater)
        }
    }
}

enum SettingsTab: CaseIterable, Identifiable {
    case watchlist
    case apiKeys
    case appearance
    case diagnostics

    var id: Self { self }

    func title(language: AppLanguage) -> String {
        switch self {
        case .watchlist:
            LocalizedCopy.text(.watchlist, language: language)
        case .apiKeys:
            LocalizedCopy.text(.apiKeys, language: language)
        case .appearance:
            LocalizedCopy.text(.appearance, language: language)
        case .diagnostics:
            LocalizedCopy.text(.diagnostics, language: language)
        }
    }

    var icon: String {
        switch self {
        case .watchlist: "list.bullet"
        case .apiKeys: "key"
        case .appearance: "paintpalette"
        case .diagnostics: "waveform.path.ecg"
        }
    }
}

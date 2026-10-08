import AppKit
import ServiceManagement
import SwiftUI

struct SettingsGeneralTab: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var loginItem = LoginItemController()

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: 10) {
                ToggleRow(
                    title: copy(.launchAtLogin),
                    isOn: Binding(
                        get: { loginItem.isRegistered },
                        set: loginItem.setEnabled,
                    ),
                )

                Text(copy(.launchAtLoginDescription))
                    .font(PixelFont.tiny)
                    .foregroundStyle(PixelColors.muted)

                Text(copy(statusKey))
                    .font(PixelFont.tiny)
                    .foregroundStyle(loginItem.status == .requiresApproval ? PixelColors.warn : PixelColors.muted)

                if let error = loginItem.errorMessage {
                    Text("\(copy(.launchAtLoginFailed)) \(error)")
                        .font(PixelFont.tiny)
                        .foregroundStyle(PixelColors.down)
                        .textSelection(.enabled)
                }

                if loginItem.status == .requiresApproval {
                    Button(copy(.openLoginItemsSettings)) {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                    .buttonStyle(PixelButtonStyle())
                }
            }
        }
        .onAppear { loginItem.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginItem.refresh()
        }
    }

    private var statusKey: CopyKey {
        switch loginItem.status {
        case .enabled: .launchAtLoginEnabled
        case .notRegistered: .launchAtLoginDisabled
        case .requiresApproval: .launchAtLoginRequiresApproval
        case .notFound: .launchAtLoginUnavailable
        @unknown default: .launchAtLoginUnavailable
        }
    }

    private func copy(_ key: CopyKey) -> String {
        LocalizedCopy.text(key, language: store.preferences.language)
    }
}

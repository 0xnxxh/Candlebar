import SwiftUI

@main
struct CandlebarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.store)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(LocalizedCopy.text(.settings, language: appDelegate.store.preferences.language)) {
                    SettingsOpener.open()
                }
            }
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: appDelegate.updaterController.updater)
            }
        }
    }
}

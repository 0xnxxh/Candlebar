import AppKit
import Sparkle
import SwiftUI

@MainActor
final class SettingsWindowPresenter {
    static let shared = SettingsWindowPresenter()

    private var window: NSWindow?
    private var updater: SPUUpdater?

    private init() {}

    func configure(updater: SPUUpdater) {
        self.updater = updater
    }

    func open(store: AppStore) {
        if let window {
            if window.isVisible {
                window.close()
                return
            }
            show(window)
            return
        }

        let hostingView = NSHostingView(
            rootView: SettingsView(updater: updater)
                .environmentObject(store)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 460),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false,
        )
        window.title = LocalizedCopy.text(.settings, language: store.preferences.language)
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        show(window)
    }

    private func show(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

import AppKit
import SwiftUI

@MainActor
final class QAWindowPresenter {
    static let shared = QAWindowPresenter()

    private var window: NSWindow?

    private init() {}

    func showIfNeeded(store: AppStore) {
        guard ProcessInfo.processInfo.environment["CANDLEBAR_QA_WINDOW"] == "1" else {
            return
        }
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingView = NSHostingView(rootView: MainPanelView().environmentObject(store))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false,
        )
        window.title = "Candlebar QA"
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}

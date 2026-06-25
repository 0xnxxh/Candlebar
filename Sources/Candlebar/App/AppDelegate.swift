import AppKit
import Sparkle
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = AppStore()
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil,
    )
    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var currentPanelSize = MainPanelLayout.collapsedSize

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
    }

    private func configureStatusItem() {
        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.target = self
            item.button?.action = #selector(togglePopover(_:))
            statusItem = item
        }

        if panel == nil {
            let hostingView = NSHostingView(rootView: makeMainPanelView())
            let panel = NSPanel(
                contentRect: NSRect(origin: .zero, size: MainPanelLayout.collapsedSize),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false,
            )
            panel.contentView = hostingView
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.isMovable = false
            panel.isReleasedWhenClosed = false
            panel.level = .statusBar
            self.panel = panel
        }

        updateStatusLabel(store.menuBarLabelText)
        store.menuBarLabelDidChange = { [weak self] text in
            self?.updateStatusLabel(text)
        }
        QAWindowPresenter.shared.showIfNeeded(store: store)
    }

    func updateStatusLabel(_ text: String) {
        statusItem?.button?.title = text
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        guard let panel else { return }

        if panel.isVisible {
            panel.orderOut(sender)
            return
        }

        currentPanelSize = MainPanelLayout.collapsedSize
        panel.setFrame(panelFrame(size: currentPanelSize, sender: sender), display: true)
        panel.orderFrontRegardless()
    }

    private func makeMainPanelView() -> some View {
        MainPanelView { [weak self] isExpanded in
            self?.resizePopover(isExpanded: isExpanded)
        }
        .environmentObject(store)
    }

    private func resizePopover(isExpanded: Bool) {
        guard let panel else { return }
        let height = isExpanded
            ? MainPanelLayout.expandedContentMaxHeight + 80
            : MainPanelLayout.collapsedSize.height
        currentPanelSize = CGSize(
            width: MainPanelLayout.width,
            height: min(height, NSScreen.main?.visibleFrame.height ?? height),
        )
        guard panel.isVisible else { return }
        let oldFrame = panel.frame
        let frame = NSRect(
            x: oldFrame.minX,
            y: oldFrame.maxY - currentPanelSize.height,
            width: currentPanelSize.width,
            height: currentPanelSize.height,
        )
        panel.setFrame(frame, display: true)
    }

    private func panelFrame(size: CGSize, sender: NSStatusBarButton) -> NSRect {
        guard let window = sender.window else {
            return NSRect(origin: .zero, size: size)
        }

        let buttonFrame = sender.convert(sender.bounds, to: nil)
        let screenFrame = window.convertToScreen(buttonFrame)
        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let x = min(
            max(screenFrame.midX - size.width / 2, visibleFrame.minX + 8),
            visibleFrame.maxX - size.width - 8,
        )
        let y = max(visibleFrame.minY + 8, screenFrame.minY - size.height - 8)

        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}

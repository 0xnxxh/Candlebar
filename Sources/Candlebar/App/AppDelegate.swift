import AppKit
import Combine
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
    private var mainPanel: NSPanel?
    private var currentPanelSize = MainPanelLayout.collapsedSize
    private var isMainPanelExpanded = false
    private var panelAnchorX: CGFloat?
    private var panelTopY: CGFloat?
    private var preferencesCancellable: AnyCancellable?
    private var outsideGlobalClickMonitor: Any?
    private var outsideLocalClickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }

    private func configureStatusItem() {
        configureMainMenu()
        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.target = self
            item.button?.action = #selector(toggleMainPanel(_:))
            statusItem = item
        }

        configureMainPanelIfNeeded()

        updateStatusLabel(store.menuBarLabelText)
        store.menuBarLabelDidChange = { [weak self] text in
            self?.updateStatusLabel(text)
        }
        SettingsWindowPresenter.shared.configure(updater: updaterController.updater)
        observePreferences()
        QAWindowPresenter.shared.showIfNeeded(store: store)
    }

    func updateStatusLabel(_ text: String) {
        statusItem?.button?.title = text
    }

    @objc private func toggleMainPanel(_ sender: NSStatusBarButton) {
        guard let mainPanel else { return }

        if mainPanel.isVisible {
            mainPanel.orderOut(sender)
            removeOutsideClickMonitors()
            return
        }

        recordPanelAnchor(from: sender)
        currentPanelSize = MainPanelLayout.size(isExpanded: isMainPanelExpanded)
        panelTopY = preferredPanelTopY(from: sender)
        mainPanel.setContentSize(currentPanelSize)
        alignMainPanelWindow()
        mainPanel.orderFrontRegardless()
        updateOutsideClickMonitors()
    }

    private func configureMainPanelIfNeeded() {
        guard mainPanel == nil else { return }
        let hostingView = NSHostingView(rootView: makeMainPanelView())
        hostingView.frame.size = MainPanelLayout.collapsedSize

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: MainPanelLayout.collapsedSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
        )
        panel.contentView = hostingView
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.isReleasedWhenClosed = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        mainPanel = panel
    }

    private func makeMainPanelView() -> some View {
        MainPanelView { [weak self] isExpanded in
            self?.resizeMainPanel(isExpanded: isExpanded)
        }
        .environmentObject(store)
    }

    private func resizeMainPanel(isExpanded: Bool) {
        guard let mainPanel else { return }
        isMainPanelExpanded = isExpanded
        capturePanelTopIfNeeded()
        currentPanelSize = MainPanelLayout.size(isExpanded: isExpanded)
        mainPanel.setContentSize(currentPanelSize)
        alignMainPanelWindow()
    }

    private func recordPanelAnchor(from button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        let screenFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        panelAnchorX = screenFrame.midX
    }

    private func preferredPanelTopY(from button: NSStatusBarButton) -> CGFloat? {
        guard let buttonWindow = button.window else { return nil }
        let screenFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        return screenFrame.minY - MainPanelLayout.menuBarGap
    }

    private func capturePanelTopIfNeeded() {
        guard let window = mainPanel, window.isVisible else { return }
        panelTopY = window.frame.maxY
    }

    private func alignMainPanelWindow() {
        guard
            let window = mainPanel,
            let anchorX = panelAnchorX,
            let topY = panelTopY
        else { return }

        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
        var frame = window.frame
        frame.origin.x = anchorX - frame.width / 2
        frame.origin.y = topY - frame.height

        if let visibleFrame {
            let inset = MainPanelLayout.screenEdgeInset
            frame.origin.x = min(
                max(frame.origin.x, visibleFrame.minX + inset),
                visibleFrame.maxX - inset - frame.width,
            )
            frame.origin.y = min(
                max(frame.origin.y, visibleFrame.minY + inset),
                visibleFrame.maxY - inset - frame.height,
            )
        }

        frame.origin.x = frame.origin.x.rounded()
        frame.origin.y = frame.origin.y.rounded()
        window.setFrame(frame, display: true, animate: false)
    }

    private func observePreferences() {
        guard preferencesCancellable == nil else { return }
        preferencesCancellable = store.$preferences
            .dropFirst()
            .sink { [weak self] preferences in
                self?.updateOutsideClickMonitors(pinMainPanel: preferences.pinMainPanel)
            }
    }

    private func updateOutsideClickMonitors(pinMainPanel: Bool? = nil) {
        removeOutsideClickMonitors()
        let isPinned = pinMainPanel ?? store.preferences.pinMainPanel
        guard let mainPanel, mainPanel.isVisible, !isPinned else {
            return
        }
        outsideGlobalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in
                self?.closeMainPanelIfClickIsOutside(event)
            }
        }
        outsideLocalClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.closeMainPanelIfClickIsOutside(event)
            return event
        }
    }

    private func closeMainPanelIfClickIsOutside(_ event: NSEvent) {
        guard let mainPanel, mainPanel.isVisible else {
            removeOutsideClickMonitors()
            return
        }
        guard !store.preferences.pinMainPanel else {
            removeOutsideClickMonitors()
            return
        }
        let point = screenPoint(for: event)
        if let statusButton = statusItem?.button, statusButtonFrame(statusButton).contains(point) {
            return
        }
        guard !mainPanel.frame.contains(point) else {
            return
        }
        mainPanel.orderOut(event)
        removeOutsideClickMonitors()
    }

    private func statusButtonFrame(_ button: NSStatusBarButton) -> NSRect {
        guard let buttonWindow = button.window else { return .zero }
        return buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func removeOutsideClickMonitors() {
        if let outsideGlobalClickMonitor {
            NSEvent.removeMonitor(outsideGlobalClickMonitor)
            self.outsideGlobalClickMonitor = nil
        }
        if let outsideLocalClickMonitor {
            NSEvent.removeMonitor(outsideLocalClickMonitor)
            self.outsideLocalClickMonitor = nil
        }
    }

    private func screenPoint(for event: NSEvent) -> NSPoint {
        guard let window = event.window else {
            return event.locationInWindow
        }
        return window.convertPoint(toScreen: event.locationInWindow)
    }

    private func configureMainMenu() {
        guard NSApp.mainMenu == nil else { return }
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: LocalizedCopy.text(.settings, language: store.preferences.language),
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ",",
        )
        appMenu.addItem(
            withTitle: "Check for Updates...",
            action: #selector(checkForUpdatesFromMenu),
            keyEquivalent: "",
        )
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(
            withTitle: LocalizedCopy.text(.quit, language: store.preferences.language),
            action: #selector(quitFromMenu),
            keyEquivalent: "q",
        )
        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    @objc private func openSettingsFromMenu() {
        SettingsOpener.open(store: store)
    }

    @objc private func checkForUpdatesFromMenu() {
        updaterController.updater.checkForUpdates()
    }

    @objc private func quitFromMenu() {
        NSApplication.shared.terminate(nil)
    }
}

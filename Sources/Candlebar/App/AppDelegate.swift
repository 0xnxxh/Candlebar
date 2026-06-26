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
    private var popover: NSPopover?
    private var currentPanelSize = MainPanelLayout.collapsedSize
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
            item.button?.action = #selector(togglePopover(_:))
            statusItem = item
        }

        if popover == nil {
            let hostingController = NSHostingController(rootView: makeMainPanelView())
            hostingController.view.frame.size = MainPanelLayout.collapsedSize
            let popover = NSPopover()
            popover.contentSize = MainPanelLayout.collapsedSize
            popover.contentViewController = hostingController
            popover.animates = false
            popover.behavior = .applicationDefined
            self.popover = popover
        }

        updateStatusLabel(store.menuBarLabelText)
        store.menuBarLabelDidChange = { [weak self] text in
            self?.updateStatusLabel(text)
        }
        observePreferences()
        QAWindowPresenter.shared.showIfNeeded(store: store)
    }

    func updateStatusLabel(_ text: String) {
        statusItem?.button?.title = text
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        guard let popover else { return }

        if popover.isShown {
            popover.performClose(sender)
            removeOutsideClickMonitors()
            return
        }

        currentPanelSize = MainPanelLayout.collapsedSize
        popover.contentSize = currentPanelSize
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        updateOutsideClickMonitors()
    }

    private func makeMainPanelView() -> some View {
        MainPanelView { [weak self] isExpanded in
            self?.resizePopover(isExpanded: isExpanded)
        }
        .environmentObject(store)
    }

    private func resizePopover(isExpanded: Bool) {
        guard let popover else { return }
        let height = isExpanded
            ? MainPanelLayout.expandedContentMaxHeight + 80
            : MainPanelLayout.collapsedSize.height
        currentPanelSize = CGSize(
            width: MainPanelLayout.width,
            height: min(height, NSScreen.main?.visibleFrame.height ?? height),
        )
        popover.contentSize = currentPanelSize
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
        guard let popover, popover.isShown, !isPinned else {
            return
        }
        outsideGlobalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in
                self?.closePopoverIfClickIsOutside(event)
            }
        }
        outsideLocalClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.closePopoverIfClickIsOutside(event)
            return event
        }
    }

    private func closePopoverIfClickIsOutside(_ event: NSEvent) {
        guard let popover, popover.isShown else {
            removeOutsideClickMonitors()
            return
        }
        guard !store.preferences.pinMainPanel else {
            removeOutsideClickMonitors()
            return
        }
        guard let window = popover.contentViewController?.view.window else {
            popover.performClose(event)
            removeOutsideClickMonitors()
            return
        }
        let point = screenPoint(for: event)
        guard !window.frame.contains(point) else {
            return
        }
        popover.performClose(event)
        removeOutsideClickMonitors()
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

import AppKit
import Combine
import SwiftUI

@MainActor
final class SidebarSelection: ObservableObject {
    @Published var selectedItemID: String?
}

/// Owns the always-on-screen edge rail and the bubble that pops out of it.
/// Independent from the status item panel in `AppDelegate`.
@MainActor
final class SidebarController {
    private let store: AppStore
    private let selection = SidebarSelection()
    /// Called with the bubble's screen anchor when the user asks for the full panel.
    var onOpenMainPanel: ((_ anchorX: CGFloat, _ topY: CGFloat, _ visibleFrame: NSRect?) -> Void)?

    private var railPanel: NSPanel?
    private var bubblePanel: NSPanel?
    private var selectedIndex: Int?
    /// The rail panel's frame only identifies a display once it has been laid
    /// out; before that it still carries its placeholder origin.
    private var didLayoutRail = false
    private var dragGrabOffset: CGSize?
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var screenObserver: NSObjectProtocol?

    init(store: AppStore) {
        self.store = store
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main,
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                // Re-resolve from the remembered display: the old frame may now
                // point at a screen that was moved or unplugged.
                self.didLayoutRail = false
                self.layoutRail(preferences: self.store.preferences)
                self.hideBubble()
            }
        }
    }

    isolated deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    func apply(preferences: AppPreferences) {
        guard preferences.showSidebar else {
            hideBubble()
            railPanel?.orderOut(nil)
            return
        }
        configureRailIfNeeded()
        // Laid out from the emitted value: `@Published` fires on willSet, so
        // `store.preferences` is still the previous value here.
        layoutRail(preferences: preferences)
        railPanel?.orderFrontRegardless()
        // Item count changes move every row, so a visible bubble would end up
        // pointing at the wrong one.
        hideBubble()
    }

    // MARK: - Rail

    private func configureRailIfNeeded() {
        guard railPanel == nil else { return }
        let hostingView = NSHostingView(rootView: makeRailView())
        let panel = makePanel(level: .floating)
        panel.contentView = hostingView
        railPanel = panel
    }

    private func makeRailView() -> some View {
        SidebarRailContainer(
            selection: selection,
            onSelect: { [weak self] item, index in
                self?.toggleBubble(item: item, index: index)
            },
            onDragChanged: { [weak self] in
                self?.dragRail()
            },
            onDragEnded: { [weak self] in
                self?.endRailDrag()
            },
        )
        .environmentObject(store)
    }

    private func layoutRail(preferences: AppPreferences) {
        guard let railPanel, let visibleFrame = targetVisibleFrame() else { return }
        let frame = SidebarLayout.railFrame(
            visibleFrame: visibleFrame,
            itemCount: store.sidebarItems(for: preferences).count,
            edge: preferences.sidebarEdge,
            verticalPosition: preferences.sidebarVerticalPosition,
        )
        railPanel.setFrame(frame, display: true, animate: false)
        didLayoutRail = true
    }

    // MARK: - Dragging

    private func dragRail() {
        guard let railPanel else { return }
        // Tracked against absolute mouse coordinates. SwiftUI's drag translation
        // is relative to a window that this very gesture is moving, which feeds
        // back into itself and makes the rail jitter.
        let mouse = NSEvent.mouseLocation
        let offset = dragGrabOffset ?? {
            let initial = CGSize(
                width: mouse.x - railPanel.frame.minX,
                height: mouse.y - railPanel.frame.minY,
            )
            dragGrabOffset = initial
            hideBubble()
            return initial
        }()

        // Clamped against the screen under the pointer, not the rail's current
        // one, so the rail can be dragged onto another display.
        guard let visibleFrame = (screen(containing: mouse) ?? targetScreen())?.visibleFrame else { return }
        var frame = railPanel.frame
        frame.origin = NSPoint(x: mouse.x - offset.width, y: mouse.y - offset.height)
        railPanel.setFrameOrigin(SidebarLayout.clampedDragFrame(frame, visibleFrame: visibleFrame).origin)
    }

    private func endRailDrag() {
        defer { dragGrabOffset = nil }
        guard dragGrabOffset != nil, let railPanel else { return }
        let frame = railPanel.frame
        guard let screen = screen(bestOverlapping: frame) ?? targetScreen() else { return }
        let visibleFrame = screen.visibleFrame
        store.updateSidebarPlacement(
            edge: SidebarLayout.resolvedEdge(railCenterX: frame.midX, visibleFrame: visibleFrame),
            verticalPosition: SidebarLayout.verticalPosition(railFrame: frame, visibleFrame: visibleFrame),
            screenNumber: screen.displayNumber,
        )
        // The preference change re-enters `apply(preferences:)`, which snaps the
        // rail back onto the resolved edge.
    }

    private func targetVisibleFrame() -> NSRect? {
        targetScreen()?.visibleFrame
    }

    /// The screen the rail lives on. `NSScreen.main` follows keyboard focus, so
    /// using it here would yank the rail onto whatever display the user just
    /// clicked in. Order: where the rail already is, then the remembered
    /// display, then the focused one as a last resort.
    private func targetScreen() -> NSScreen? {
        let screens = NSScreen.screens
        if didLayoutRail, let frame = railPanel?.frame, let screen = screen(bestOverlapping: frame) {
            return screen
        }
        if let index = SidebarLayout.resolvedScreenIndex(
            preferredNumber: store.preferences.sidebarScreenNumber,
            screenNumbers: screens.map(\.displayNumber),
        ) {
            return screens[index]
        }
        return NSScreen.main ?? screens.first
    }

    /// Screen holding the largest slice of `frame`; a rail straddling two
    /// displays belongs to the one showing most of it.
    private func screen(bestOverlapping frame: NSRect) -> NSScreen? {
        var best: NSScreen?
        var bestArea: CGFloat = 0
        for screen in NSScreen.screens {
            let overlap = screen.frame.intersection(frame)
            guard !overlap.isNull else { continue }
            let area = overlap.width * overlap.height
            if area > bestArea {
                bestArea = area
                best = screen
            }
        }
        return best
    }

    /// Screen under the pointer, so a drag can carry the rail across displays.
    private func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    // MARK: - Bubble

    private func toggleBubble(item: SidebarItem, index: Int) {
        if case let .symbol(symbol) = item {
            store.setDefault(symbol)
        }
        guard selection.selectedItemID != item.id else {
            hideBubble()
            return
        }
        showBubble(item: item, index: index)
    }

    private func showBubble(item: SidebarItem, index: Int) {
        guard
            let railPanel,
            let visibleFrame = targetVisibleFrame()
        else { return }

        // Measure the real content first: a fixed size leaves dead space on
        // short cards and clips the wider account summary.
        let measuringView = NSHostingView(rootView: makeBubbleView(item: item, onOpen: {}))
        let size = measuringView.fittingSize

        let frame = SidebarLayout.bubbleFrame(
            railFrame: railPanel.frame,
            itemIndex: index,
            bubbleSize: size,
            visibleFrame: visibleFrame,
            edge: store.preferences.sidebarEdge,
        )
        let panel = bubblePanel ?? {
            let created = makePanel(level: .popUpMenu)
            bubblePanel = created
            return created
        }()

        panel.contentView = NSHostingView(
            rootView: makeBubbleView(item: item) { [weak self] in
                self?.openMainPanel(from: frame, visibleFrame: visibleFrame)
            },
        )
        panel.setFrame(frame, display: true, animate: false)
        panel.orderFrontRegardless()

        selection.selectedItemID = item.id
        selectedIndex = index
        installOutsideClickMonitors()
    }

    private func makeBubbleView(
        item: SidebarItem,
        onOpen: @escaping () -> Void,
    ) -> some View {
        SidebarBubbleView(item: item, onOpenMainPanel: onOpen)
            .environmentObject(store)
    }

    private func hideBubble() {
        selection.selectedItemID = nil
        selectedIndex = nil
        bubblePanel?.orderOut(nil)
        removeOutsideClickMonitors()
    }

    private func openMainPanel(from bubbleFrame: NSRect, visibleFrame: NSRect) {
        hideBubble()
        onOpenMainPanel?(bubbleFrame.midX, bubbleFrame.maxY, visibleFrame)
    }

    // MARK: - Panels and monitors

    private func makePanel(level: NSWindow.Level) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: CGSize(width: SidebarLayout.railWidth, height: 200)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
        )
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.isReleasedWhenClosed = false
        panel.level = level
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        return panel
    }

    private func installOutsideClickMonitors() {
        removeOutsideClickMonitors()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            DispatchQueue.main.async {
                self?.hideBubbleIfClickIsOutside(event)
            }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.hideBubbleIfClickIsOutside(event)
            return event
        }
    }

    private func hideBubbleIfClickIsOutside(_ event: NSEvent) {
        guard let bubblePanel, bubblePanel.isVisible else {
            removeOutsideClickMonitors()
            return
        }
        let point = screenPoint(for: event)
        // Clicks on the rail are handled by the rail buttons themselves.
        if bubblePanel.frame.contains(point) || railPanel?.frame.contains(point) == true {
            return
        }
        hideBubble()
    }

    private func removeOutsideClickMonitors() {
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
        }
    }

    private func screenPoint(for event: NSEvent) -> NSPoint {
        guard let window = event.window else {
            return event.locationInWindow
        }
        return window.convertPoint(toScreen: event.locationInWindow)
    }
}

private struct SidebarRailContainer: View {
    @ObservedObject var selection: SidebarSelection
    var onSelect: (SidebarItem, Int) -> Void
    var onDragChanged: () -> Void
    var onDragEnded: () -> Void

    var body: some View {
        SidebarRailView(
            selectedItemID: selection.selectedItemID,
            onSelect: onSelect,
            onDragChanged: onDragChanged,
            onDragEnded: onDragEnded,
        )
    }
}

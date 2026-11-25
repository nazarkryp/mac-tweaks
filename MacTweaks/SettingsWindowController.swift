import AppKit
import SwiftUI

/// Owns the Settings window. It is an AppKit window, not a SwiftUI `Settings` scene, so the app
/// can open it from anywhere: the menu bar item, and a relaunch when the menu bar item is hidden.
/// The tabs are toolbar items of an `NSTabViewController`. Each tab is a SwiftUI view.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let store: SettingsStore
    private var window: NSWindow?

    init(store: SettingsStore) {
        self.store = store
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        // The app has no Dock icon (LSUIElement). Show it while Settings is open,
        // so the window comes to the front and appears in Cmd-Tab.
        // The policy change takes effect only after the current run loop turn. An activation
        // in the same turn fails, and the window opens behind the active app.
        guard NSApp.activationPolicy() != .regular else {
            bringToFront(window)
            return
        }
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async { [weak self] in
            self?.bringToFront(window)
        }
    }

    private func bringToFront(_ window: NSWindow) {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func makeWindow() -> NSWindow {
        let tabs = SettingsTabViewController()
        tabs.tabStyle = .toolbar
        tabs.transitionOptions = [.crossfade, .allowUserInteraction]
        tabs.addTabViewItem(tab(MenuItemsTab(), label: "Menu", symbol: "contextualmenu.and.cursorarrow"))
        tabs.addTabViewItem(tab(TemplatesTab(), label: "New File", symbol: "doc.badge.plus"))
        tabs.addTabViewItem(tab(GeneralTab(), label: "General", symbol: "gearshape"))

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.setFrameAutosaveName("MacTweaksSettings")
        return window
    }

    private func tab(_ view: some View, label: String, symbol: String) -> NSTabViewItem {
        let controller = NSHostingController(rootView: view.environment(store))
        // The tab reports its SwiftUI size, so the window opens at that size.
        controller.sizingOptions = .preferredContentSize
        // The window shows the title of the selected tab.
        controller.title = label
        let item = NSTabViewItem(viewController: controller)
        item.label = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        return item
    }
}

/// Sizes the window to the tabs when it opens. All tabs have the same size, so the window keeps
/// its size when the user changes the tab.
private final class SettingsTabViewController: NSTabViewController {
    override func viewDidAppear() {
        super.viewDidAppear()
        fitWindowToSelectedTab()
    }

    private var selectedController: NSViewController? {
        tabViewItems.indices.contains(selectedTabViewItemIndex) ? tabViewItems[selectedTabViewItemIndex].viewController : nil
    }

    /// Keeps the top-left corner in place, so the toolbar does not move.
    private func fitWindowToSelectedTab() {
        guard let window = view.window, let contentView = window.contentView,
              let size = selectedController?.preferredContentSize, size.width > 0, size.height > 0 else { return }
        let current = contentView.frame.size
        var frame = window.frame
        frame.origin.y += current.height - size.height
        frame.size.width += size.width - current.width
        frame.size.height += size.height - current.height
        guard frame != window.frame else { return }
        window.setFrame(frame, display: true)
    }
}

/// Preferences of the host app only. The Finder extension does not read them.
enum HostPreferences {
    static let showMenuBarIconKey = "showMenuBarIcon"
}

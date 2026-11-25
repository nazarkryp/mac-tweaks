import Cocoa
import FinderSync
import os

nonisolated private let logger = Logger(subsystem: "com.nazarkryp.MacTweaks.FinderExtension", category: "FinderSync")

/// Runs `body` on the main thread and waits for it.
/// Finder calls the extension from a background XPC queue, but AppKit menus must be used
/// on the main thread. The XPC queue is never the main queue, so `main.sync` cannot deadlock.
nonisolated private func runOnMain(_ body: @MainActor () -> Void) {
    if Thread.isMainThread {
        MainActor.assumeIsolated(body)
    } else {
        DispatchQueue.main.sync { MainActor.assumeIsolated(body) }
    }
}

/// Builds the MacTweaks items in the Finder context menu.
/// Copy Path runs here. The other actions go to the host app as `mactweaks://` URLs,
/// so this sandboxed extension needs no file-system access.
final class FinderSync: FIFinderSync {
    private var volumeTimer: DispatchSourceTimer?

    // FIFinderSync has no actor annotations, and Finder calls it from a background queue.
    // Each entry point is nonisolated and moves to the main thread with `runOnMain`.
    nonisolated override init() {
        super.init()
        runOnMain { startWatchingVolumes() }
    }

    private func startWatchingVolumes() {
        updateDirectoryURLs()

        // Finder Sync does not cross volume mount points, so each mounted volume must be
        // in `directoryURLs`. Mount notifications are not reliable in this extension, so poll.
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 3, repeating: 3, leeway: .seconds(1))
        timer.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.updateDirectoryURLs() }
        }
        timer.resume()
        volumeTimer = timer
    }

    isolated deinit {
        volumeTimer?.cancel()
    }

    private func updateDirectoryURLs() {
        var urls: Set<URL> = [URL(fileURLWithPath: "/")]
        let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: nil,
            options: [.skipHiddenVolumes]
        ) ?? []
        urls.formUnion(volumes)

        let controller = FIFinderSyncController.default()
        if controller.directoryURLs != urls {
            controller.directoryURLs = urls
        }
    }

    // MARK: - Menu

    nonisolated override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        // NSMenu is not Sendable. Finder takes ownership of the returned menu and the main
        // thread does not use it after `runOnMain` returns, so the handoff is safe.
        nonisolated(unsafe) var menu: NSMenu?
        runOnMain { menu = makeMenu(for: menuKind) }
        return menu
    }

    private func makeMenu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems || menuKind == .contextualMenuForContainer else {
            return nil
        }

        let menu = NSMenu(title: "")
        let settings: AppSettings
        do {
            settings = try SharedStore.loadSettings()
        } catch {
            logger.error("Cannot load settings: \(error.localizedDescription, privacy: .public)")
            menu.addItem(withTitle: "MacTweaks: settings cannot be read. Open MacTweaks Settings.", action: nil, keyEquivalent: "")
            return menu
        }

        if settings.showCopyPath {
            menu.addItem(item("Copy Path", symbol: "doc.on.doc", action: #selector(copyPath(_:))))
        }
        if settings.showOpenTerminal {
            menu.addItem(item("Open in \(settings.terminal.name)", symbol: "terminal", action: #selector(openTerminal(_:))))
        }
        if settings.showOpenEditor {
            menu.addItem(item("Open in \(settings.editor.name)", symbol: "chevron.left.forwardslash.chevron.right", action: #selector(openEditor(_:))))
        }
        if settings.showNewFile {
            let submenu = NSMenu(title: "")
            for (index, template) in settings.templates.enumerated()
            where template.isEnabled && template.validationError == nil {
                let templateItem = item(template.title, symbol: "doc", action: #selector(newFile(_:)))
                // Finder copies menu items and drops `representedObject`; `tag` survives.
                templateItem.tag = index
                submenu.addItem(templateItem)
            }
            if !submenu.items.isEmpty {
                let newFileItem = NSMenuItem(title: "New File", action: nil, keyEquivalent: "")
                newFileItem.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: nil)
                newFileItem.submenu = submenu
                menu.addItem(newFileItem)
            }
        }
        return menu
    }

    private func item(_ title: String, symbol: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        return item
    }

    // MARK: - Actions
    // Finder calls the actions from a background queue too, so each one moves to the main thread.

    @objc nonisolated private func copyPath(_ sender: NSMenuItem) {
        runOnMain { copyTargetPaths() }
    }

    @objc nonisolated private func openTerminal(_ sender: NSMenuItem) {
        runOnMain { send(.openTerminal, paths: targetPaths()) }
    }

    @objc nonisolated private func openEditor(_ sender: NSMenuItem) {
        runOnMain { send(.openEditor, paths: targetPaths()) }
    }

    @objc nonisolated private func newFile(_ sender: NSMenuItem) {
        // `runOnMain` waits for the closure, so the sender is used on one thread at a time.
        nonisolated(unsafe) let item = sender
        runOnMain { createFile(templateIndex: item.tag) }
    }

    private func copyTargetPaths() {
        let paths = targetPaths()
        guard !paths.isEmpty else {
            logger.error("Copy Path: Finder gave no target")
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(paths.joined(separator: "\n"), forType: .string)
    }

    private func createFile(templateIndex: Int) {
        guard let folder = FIFinderSyncController.default().targetedURL() else {
            logger.error("New File: Finder gave no target folder")
            return
        }
        let templates: [FileTemplate]
        do {
            templates = try SharedStore.loadSettings().templates
        } catch {
            logger.error("New File: cannot load settings: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard templates.indices.contains(templateIndex) else {
            logger.error("New File: no template at index \(templateIndex)")
            return
        }
        send(.newFile, paths: [folder.path], templateID: templates[templateIndex].id)
    }

    /// The selected items, or the open folder when nothing is selected.
    private func targetPaths() -> [String] {
        let controller = FIFinderSyncController.default()
        if let selected = controller.selectedItemURLs(), !selected.isEmpty {
            return selected.map(\.path)
        }
        if let folder = controller.targetedURL() {
            return [folder.path]
        }
        return []
    }

    private func send(_ action: MenuAction, paths: [String], templateID: UUID? = nil) {
        guard !paths.isEmpty else {
            logger.error("\(action.rawValue, privacy: .public): Finder gave no target")
            return
        }
        let token: String
        do {
            token = try SharedStore.actionToken()
        } catch {
            logger.error("\(action.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return
        }
        let request = ActionRequest(action: action, paths: paths, templateID: templateID, token: token)
        guard let url = request.url() else {
            logger.error("\(action.rawValue, privacy: .public): cannot build the action URL")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.open(url, configuration: configuration) { _, error in
            if let error {
                logger.error("Cannot send \(action.rawValue, privacy: .public) to MacTweaks: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

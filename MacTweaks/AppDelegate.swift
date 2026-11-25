import AppKit
import FinderSync

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settingsStore = SettingsStore()
    private lazy var settingsWindow = SettingsWindowController(store: settingsStore)

    private static let didEnableExtensionKey = "didEnableFinderExtension"

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Handle `mactweaks://` URLs here, not with SwiftUI `onOpenURL`.
        // SwiftUI opens a window to deliver a URL; this app must stay in the menu bar.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            // Create the token now, so the extension finds it on its first action.
            _ = try SharedStore.actionToken()
        } catch {
            ErrorReporter.report(error, context: "MacTweaks cannot start")
        }
        enableExtensionOnFirstLaunch()

        // With the menu bar icon hidden, a launch by the user must show something.
        // A launch at login stays silent.
        let showsMenuBarIcon = UserDefaults.standard.object(forKey: HostPreferences.showMenuBarIconKey) as? Bool ?? true
        if !showsMenuBarIcon && !launchedAsLoginItem {
            showSettings()
        }
    }

    /// Called when the user opens the app while it already runs, for example from Spotlight.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    func showSettings() {
        settingsWindow.show()
    }

    private var launchedAsLoginItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventID == AEEventID(kAEOpenApplication)
        else { return false }
        return event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
    }

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: string)
        else {
            ErrorReporter.report(ActionRequest.DecodeError.notActionURL, context: "Unknown request")
            return
        }
        Task {
            do {
                try await ActionRouter.handle(url)
            } catch {
                ErrorReporter.report(error, context: "The Finder action failed")
            }
        }
    }

    /// Turns the Finder extension on once. After that, the user controls it in System Settings.
    private func enableExtensionOnFirstLaunch() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.didEnableExtensionKey) else { return }
        defaults.set(true, forKey: Self.didEnableExtensionKey)
        guard !FIFinderSyncController.isExtensionEnabled,
              let appID = Bundle.main.bundleIdentifier
        else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = ["-e", "use", "-i", "\(appID).FinderExtension"]
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                ErrorReporter.report(
                    ExtensionError.pluginkitFailed(process.terminationStatus),
                    context: "Cannot turn on the Finder extension"
                )
            }
        } catch {
            ErrorReporter.report(error, context: "Cannot turn on the Finder extension")
        }
    }

    private enum ExtensionError: LocalizedError {
        case pluginkitFailed(Int32)

        var errorDescription: String? {
            switch self {
            case .pluginkitFailed(let status):
                "pluginkit stopped with status \(status). Turn the extension on in MacTweaks Settings > General."
            }
        }
    }
}

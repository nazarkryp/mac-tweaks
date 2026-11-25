import AppKit

/// Opens files or folders in a chosen app. Uses Launch Services, not shell commands.
enum AppLauncher {
    enum LaunchError: LocalizedError {
        case appNotInstalled(String)

        var errorDescription: String? {
            switch self {
            case .appNotInstalled(let name): "\(name) is not installed. Choose another app in MacTweaks Settings."
            }
        }
    }

    static func open(_ items: [URL], with app: AppChoice) async throws {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID) else {
            throw LaunchError.appNotInstalled(app.name)
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        _ = try await NSWorkspace.shared.open(items, withApplicationAt: appURL, configuration: configuration)
    }

    static func isInstalled(_ app: AppChoice) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID) != nil
    }
}

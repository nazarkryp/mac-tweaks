import Foundation
import Security

/// An app that a Finder action opens, for example a terminal or an editor.
struct AppChoice: Codable, Hashable, Identifiable, Sendable {
    var bundleID: String
    var name: String

    var id: String { bundleID }
}

enum KnownApps {
    static let terminals: [AppChoice] = [
        AppChoice(bundleID: "com.apple.Terminal", name: "Terminal"),
        AppChoice(bundleID: "com.googlecode.iterm2", name: "iTerm"),
        AppChoice(bundleID: "dev.warp.Warp-Stable", name: "Warp"),
        AppChoice(bundleID: "com.mitchellh.ghostty", name: "Ghostty"),
    ]

    static let editors: [AppChoice] = [
        AppChoice(bundleID: "com.microsoft.VSCode", name: "VS Code"),
        AppChoice(bundleID: "com.todesktop.230313mzl4w4u92", name: "Cursor"),
        AppChoice(bundleID: "dev.zed.Zed", name: "Zed"),
        AppChoice(bundleID: "com.sublimetext.4", name: "Sublime Text"),
        AppChoice(bundleID: "com.apple.dt.Xcode", name: "Xcode"),
    ]
}

/// One item of the "New File" submenu.
struct FileTemplate: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var title: String
    var fileName: String
    var content: String
    var isEnabled: Bool

    init(id: UUID = UUID(), title: String, fileName: String, content: String = "", isEnabled: Bool = true) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.content = content
        self.isEnabled = isEnabled
    }

    /// A message for the user when the template cannot create a file, else nil.
    var validationError: String? {
        if title.trimmingCharacters(in: .whitespaces).isEmpty {
            return "The menu title is empty."
        }
        if fileName.isEmpty {
            return "The file name is empty."
        }
        if fileName.contains("/") || fileName.contains(":") || fileName.contains("\0") {
            return "The file name must not contain \"/\" or \":\"."
        }
        if fileName == "." || fileName == ".." {
            return "The file name is not valid."
        }
        return nil
    }

    static let defaults: [FileTemplate] = [
        FileTemplate(title: "Text File", fileName: "Untitled.txt"),
        FileTemplate(title: "Markdown File", fileName: "Untitled.md", content: "# Untitled\n"),
        FileTemplate(title: "JSON File", fileName: "Untitled.json", content: "{\n}\n"),
        FileTemplate(title: "Shell Script", fileName: "script.sh", content: "#!/bin/zsh\n\n"),
        FileTemplate(title: ".gitignore", fileName: ".gitignore", content: ".DS_Store\n", isEnabled: false),
    ]
}

/// The user settings. The host app writes them; the Finder extension reads them.
struct AppSettings: Codable, Equatable, Sendable {
    var showCopyPath = true
    var showOpenTerminal = true
    var showOpenEditor = true
    var showNewFile = true
    var terminal = KnownApps.terminals[0]
    var editor = KnownApps.editors[0]
    var templates = FileTemplate.defaults
}

/// Reads and writes the data that the host app and the Finder extension share
/// through the App Group `UserDefaults` suite.
enum SharedStore {
    private static let settingsKey = "settings.v1"
    private static let tokenKey = "actionToken"
    nonisolated private static let appGroupInfoKey = "MTAppGroupIdentifier"

    enum StoreError: LocalizedError {
        case appGroupNotConfigured
        case appGroupUnavailable(String)
        case settingsUnreadable(underlying: Error)
        case tokenGenerationFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .appGroupNotConfigured:
                "The app bundle has no \(SharedStore.appGroupInfoKey) value."
            case .appGroupUnavailable(let id):
                "The shared settings for App Group \(id) are not available."
            case .settingsUnreadable(let underlying):
                "The saved settings cannot be read: \(underlying.localizedDescription)"
            case .tokenGenerationFailed(let status):
                "The action token cannot be created (status \(status))."
            }
        }
    }

    static func loadSettings() throws(StoreError) -> AppSettings {
        guard let data = try defaults().data(forKey: settingsKey) else {
            return AppSettings()
        }
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            throw .settingsUnreadable(underlying: error)
        }
    }

    static func save(_ settings: AppSettings) throws {
        let data = try JSONEncoder().encode(settings)
        try defaults().set(data, forKey: settingsKey)
    }

    /// The secret that the extension adds to each action URL. The host app accepts only URLs with it.
    static func actionToken() throws(StoreError) -> String {
        let store = try defaults()
        if let token = store.string(forKey: tokenKey), !token.isEmpty {
            return token
        }
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { throw .tokenGenerationFailed(status) }
        let token = bytes.map { String(format: "%02x", $0) }.joined()
        store.set(token, forKey: tokenKey)
        return token
    }

    private static func defaults() throws(StoreError) -> UserDefaults {
        guard let id = Bundle.main.object(forInfoDictionaryKey: appGroupInfoKey) as? String, !id.isEmpty else {
            throw .appGroupNotConfigured
        }
        guard let store = UserDefaults(suiteName: id) else {
            throw .appGroupUnavailable(id)
        }
        return store
    }
}

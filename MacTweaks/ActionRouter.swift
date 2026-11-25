import AppKit

/// Checks a `mactweaks://` request from the Finder extension and runs it.
enum ActionRouter {
    enum RouterError: LocalizedError {
        case invalidToken
        case invalidPath(String)
        case notAFolder(String)
        case templateNotFound
        case singleFolderRequired

        var errorDescription: String? {
            switch self {
            case .invalidToken: "The request did not come from the MacTweaks Finder extension."
            case .invalidPath(let path): "The item \"\(path)\" does not exist."
            case .notAFolder(let path): "\"\(path)\" is not a folder."
            case .templateNotFound: "The file template does not exist anymore. Check MacTweaks Settings."
            case .singleFolderRequired: "A new file needs exactly one target folder."
            }
        }
    }

    static func handle(_ url: URL) async throws {
        let request = try ActionRequest(url: url)
        guard request.token == (try SharedStore.actionToken()) else {
            throw RouterError.invalidToken
        }
        let items = try request.paths.map(existingFileURL)
        let settings = try SharedStore.loadSettings()

        switch request.action {
        case .openTerminal:
            try await AppLauncher.open(folders(containing: items), with: settings.terminal)
        case .openEditor:
            try await AppLauncher.open(items, with: settings.editor)
        case .newFile:
            guard items.count == 1 else { throw RouterError.singleFolderRequired }
            let folder = items[0]
            guard isDirectory(folder) else { throw RouterError.notAFolder(folder.path) }
            guard let template = settings.templates.first(where: { $0.id == request.templateID }) else {
                throw RouterError.templateNotFound
            }
            let file = try FileCreator.create(template, in: folder)
            NSWorkspace.shared.activateFileViewerSelecting([file])
        }
    }

    private static func existingFileURL(_ path: String) throws -> URL {
        guard path.hasPrefix("/") else { throw RouterError.invalidPath(path) }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { throw RouterError.invalidPath(path) }
        return url
    }

    /// Each folder as itself and each file as its parent folder, without duplicates.
    private static func folders(containing items: [URL]) -> [URL] {
        var seen = Set<URL>()
        return items
            .map { isDirectory($0) ? $0 : $0.deletingLastPathComponent() }
            .filter { seen.insert($0).inserted }
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}

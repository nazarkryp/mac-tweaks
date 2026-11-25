import Foundation

/// An action that the Finder extension asks the host app to run.
/// Copy Path is not here: the extension runs it itself.
enum MenuAction: String, Sendable {
    case openTerminal
    case openEditor
    case newFile
}

/// A request from the Finder extension to the host app, sent as a `mactweaks://run?...` URL.
struct ActionRequest: Equatable, Sendable {
    static let scheme = "mactweaks"
    static let host = "run"

    let action: MenuAction
    let paths: [String]
    let templateID: UUID?
    let token: String

    init(action: MenuAction, paths: [String], templateID: UUID? = nil, token: String) {
        self.action = action
        self.paths = paths
        self.templateID = templateID
        self.token = token
    }

    init(url: URL) throws(DecodeError) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == Self.scheme,
              components.host == Self.host
        else { throw .notActionURL }

        let items = components.queryItems ?? []
        func values(_ name: String) -> [String] {
            items.filter { $0.name == name }.compactMap(\.value)
        }

        guard let rawAction = values("action").first else { throw .missing("action") }
        guard let action = MenuAction(rawValue: rawAction) else { throw .invalid("action") }
        guard let token = values("token").first, !token.isEmpty else { throw .missing("token") }

        let paths = values("path")
        guard !paths.isEmpty else { throw .missing("path") }

        var templateID: UUID?
        if let rawTemplate = values("template").first {
            guard let id = UUID(uuidString: rawTemplate) else { throw .invalid("template") }
            templateID = id
        }
        if action == .newFile, templateID == nil { throw .missing("template") }

        self.init(action: action, paths: paths, templateID: templateID, token: token)
    }

    func url() -> URL? {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.host
        var items = [
            URLQueryItem(name: "action", value: action.rawValue),
            URLQueryItem(name: "token", value: token),
        ]
        items += paths.map { URLQueryItem(name: "path", value: $0) }
        if let templateID {
            items.append(URLQueryItem(name: "template", value: templateID.uuidString))
        }
        components.queryItems = items
        return components.url
    }

    enum DecodeError: LocalizedError, Equatable {
        case notActionURL
        case missing(String)
        case invalid(String)

        var errorDescription: String? {
            switch self {
            case .notActionURL: "The URL is not a MacTweaks action."
            case .missing(let name): "The action URL has no \(name) value."
            case .invalid(let name): "The action URL has an invalid \(name) value."
            }
        }
    }
}

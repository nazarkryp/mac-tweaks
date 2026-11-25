import Foundation

/// Creates a new file from a template. It never replaces an existing file.
enum FileCreator {
    private static let maxAttempts = 999

    enum CreateError: LocalizedError {
        case invalidTemplate(String)
        case noFreeName(String)

        var errorDescription: String? {
            switch self {
            case .invalidTemplate(let message): "The template is not valid: \(message)"
            case .noFreeName(let name): "Too many files named like \"\(name)\" exist in this folder."
            }
        }
    }

    /// Writes the template to `folder`. If the name exists, it adds a number: "Untitled 2.txt".
    static func create(_ template: FileTemplate, in folder: URL) throws -> URL {
        if let message = template.validationError {
            throw CreateError.invalidTemplate(message)
        }
        let data = Data(template.content.utf8)
        for number in 1...maxAttempts {
            let url = folder.appendingPathComponent(fileName(template.fileName, number: number), isDirectory: false)
            do {
                // `.withoutOverwriting` uses O_EXCL, so a check-then-write race cannot replace a file.
                try data.write(to: url, options: .withoutOverwriting)
                return url
            } catch CocoaError.fileWriteFileExists {
                continue
            }
        }
        throw CreateError.noFreeName(template.fileName)
    }

    static func fileName(_ name: String, number: Int) -> String {
        guard number > 1 else { return name }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        return ext.isEmpty ? "\(base) \(number)" : "\(base) \(number).\(ext)"
    }
}

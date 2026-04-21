import Foundation

struct OnboardingCompletionMarker {
    enum Failure: LocalizedError {
        case createFailed(path: String)

        var errorDescription: String? {
            switch self {
            case .createFailed(let path):
                return "Could not create \(path)"
            }
        }
    }

    static let markerPath = "~/.config/duoduo/.onboarded"
    static var homeDirectoryOverride: String?

    static func markCompletedIfNeeded() throws {
        let url = URL(fileURLWithPath: resolve(markerPath))
        guard !FileManager.default.fileExists(atPath: url.path) else { return }

        let directory = url.deletingLastPathComponent()
        let fileManager = FileManager.default

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        if !fileManager.createFile(atPath: url.path, contents: Data()) {
            throw Failure.createFailed(path: url.path)
        }
    }

    private static func resolve(_ path: String) -> String {
        guard path.hasPrefix("~") else { return path }
        let homeDirectory = homeDirectoryOverride ?? NSHomeDirectory()
        if path == "~" {
            return homeDirectory
        }
        return homeDirectory + String(path.dropFirst())
    }
}

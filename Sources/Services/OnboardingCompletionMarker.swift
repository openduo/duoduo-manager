import Foundation

struct OnboardingCompletionMarker {
    enum Failure: LocalizedError {
        case createFailed(path: String)
        case writeConfigFailed(path: String)

        var errorDescription: String? {
            switch self {
            case .createFailed(let path):
                return "Could not create \(path)"
            case .writeConfigFailed(let path):
                return "Could not write \(path)"
            }
        }
    }

    static let markerPath = "~/.config/duoduo/.onboarded"
    static var homeDirectoryOverride: String?

    static func writeConfig(daemonConfig: DaemonConfig) throws {
        try writeConfig(daemonConfig.onboardingConfigDocument)
    }

    static func hasRequiredConfiguration(daemonConfig: DaemonConfig = .load()) -> Bool {
        !daemonConfig.workDir.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func hasCompletedConfiguration(daemonConfig: DaemonConfig = .load()) -> Bool {
        isMarkedCompleted
            && hasRequiredConfiguration(daemonConfig: daemonConfig)
            && hasConfigJSONAligned(daemonConfig: daemonConfig)
    }

    static func repairDerivedFilesIfNeeded(daemonConfig: DaemonConfig) throws {
        daemonConfig.save()
        repairClaudeExecutablePath()
        if !hasConfigJSONAligned(daemonConfig: daemonConfig) {
            try writeConfig(daemonConfig: daemonConfig)
        }
        try markCompletedIfNeeded(daemonConfig: daemonConfig)
    }

    static func repairClaudeExecutablePath() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["claude"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.environment = ProcessInfo.processInfo.environment
        guard let result = try? runSynchronously(process, pipe),
              !result.isEmpty else { return }
        ConfigStore.save(
            entries: [(key: "CLAUDE_CODE_EXECUTABLE", value: result)],
            managedKeys: ["CLAUDE_CODE_EXECUTABLE"]
        )
    }

    private static func runSynchronously(_ process: Process, _ pipe: Pipe) throws -> String {
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (String(data: data, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func markCompletedIfNeeded(daemonConfig: DaemonConfig) throws {
        let url = URL(fileURLWithPath: resolve(markerPath))
        let directory = url.deletingLastPathComponent()
        let fileManager = FileManager.default

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        daemonConfig.save()
        try writeConfig(daemonConfig: daemonConfig)

        guard !fileManager.fileExists(atPath: url.path) else { return }

        if !fileManager.createFile(atPath: url.path, contents: Data()) {
            throw Failure.createFailed(path: url.path)
        }
    }

    private static var isMarkedCompleted: Bool {
        FileManager.default.fileExists(atPath: resolve(markerPath))
    }

    private static func hasConfigJSONAligned(daemonConfig: DaemonConfig) -> Bool {
        guard let document = ConfigStore.loadOnboardingConfigDocument() else {
            return false
        }

        let configWorkDir = daemonConfig.workDir.trimmingCharacters(in: .whitespacesAndNewlines)
        return !document.mode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !document.authSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !document.workDir.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && document.workDir == configWorkDir
            && document.daemonUrl == daemonConfig.daemonURL
    }

    private static func writeConfig(_ document: OnboardingConfigDocument) throws {
        do {
            try ConfigStore.writeOnboardingConfigDocument(document)
        } catch {
            throw Failure.writeConfigFailed(path: "~/.config/duoduo/config.json")
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

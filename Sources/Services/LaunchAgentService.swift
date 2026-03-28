import Foundation

struct LaunchAgentService {
    static let label = "ai.openduo.manager.daemon"

    private static var launchAgentsDir: String {
        "\(NSHomeDirectory())/Library/LaunchAgents"
    }

    static var plistPath: String {
        "\(launchAgentsDir)/\(label).plist"
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistPath)
    }

    // MARK: - Install & Start

    /// Generate plist, write to disk, and load via launchctl.
    static func install(environment: [String: String]) async throws {
        try FileManager.default.createDirectory(
            atPath: launchAgentsDir,
            withIntermediateDirectories: true
        )

        // Unload existing if present
        if isInstalled {
            try? unload()
        }

        // Write plist
        let plistContent = generatePlist(environment: environment)
        FileManager.default.createFile(atPath: plistPath, contents: Data(plistContent.utf8))

        // Load
        try load()
    }

    // MARK: - Uninstall & Stop

    /// Unload and delete the plist.
    static func uninstall() throws {
        if isInstalled {
            try? unload()
            try? FileManager.default.removeItem(atPath: plistPath)
        }
    }

    // MARK: - Plist Generation

    private static func generatePlist(environment: [String: String]) -> String {
        let nodePath = resolveNodePath()
        let daemonJsPath = resolveDaemonJsPath()
        let logPath = "\(NSHomeDirectory())/.aladuo/run/daemon-supervisor.log"

        try? FileManager.default.createDirectory(
            atPath: (logPath as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true
        )

        var envEntries = ""
        for (key, value) in environment.sorted(by: { $0.key < $1.key }) {
            envEntries += "                <key>\(escapeXml(key))</key>\n                <string>\(escapeXml(value))</string>\n"
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>

            <key>ProgramArguments</key>
            <array>
                <string>\(escapeXml(nodePath))</string>
                <string>\(escapeXml(daemonJsPath))</string>
            </array>

            <key>EnvironmentVariables</key>
            <dict>
        \(envEntries)    </dict>

            <key>StandardOutPath</key>
            <string>\(escapeXml(logPath))</string>

            <key>StandardErrorPath</key>
            <string>\(escapeXml(logPath))</string>

            <key>WorkingDirectory</key>
            <string>\(escapeXml(NodeRuntime.duoduoPackageDir ?? NSHomeDirectory()))</string>

            <key>RunAtLoad</key>
            <true/>

            <key>KeepAlive</key>
            <false/>
        </dict>
        </plist>
        """
    }

    // MARK: - launchctl helpers

    private static func load() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", plistPath]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8) ?? "unknown error"
            throw LaunchAgentError.loadFailed(msg)
        }
    }

    private static func unload() throws {
        guard isInstalled else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", plistPath]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8) ?? "unknown error"
            throw LaunchAgentError.unloadFailed(msg)
        }
    }

    // MARK: - Path Resolution

    private static func resolveNodePath() -> String {
        // Bundled node (inside app)
        if let bundled = NodeRuntime.bundledNodePath,
           FileManager.default.isExecutableFile(atPath: bundled) {
            return bundled
        }
        // System node (resolved from PATH)
        let paths = NodeRuntime.environment["PATH"]?.components(separatedBy: ":") ?? []
        for dir in paths {
            let candidate = "\(dir)/node"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        fatalError("node not found — is Node.js installed?")
    }

    private static func resolveDaemonJsPath() -> String {
        guard let packageDir = NodeRuntime.duoduoPackageDir else {
            fatalError("duoduo package dir not found — is duoduo installed?")
        }
        let daemonCjs = "\(packageDir)/dist/release/daemon.cjs"
        let daemonJs = "\(packageDir)/dist/release/daemon.js"
        if FileManager.default.fileExists(atPath: daemonCjs) {
            return daemonCjs
        }
        return daemonJs
    }

    private static func escapeXml(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
         .replacingOccurrences(of: "'", with: "&apos;")
    }
}

enum LaunchAgentError: LocalizedError {
    case loadFailed(String)
    case unloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .loadFailed(let msg): return "launchctl load failed: \(msg)"
        case .unloadFailed(let msg): return "launchctl unload failed: \(msg)"
        }
    }
}

import Foundation

struct NodeRuntime: Sendable {

    /// Bundle identifier from Info.plist
    private static let bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "ai.openduo.manager"

    /// npm global packages install directory (user-writable, persists across app updates)
    /// Note: must not contain spaces — duoduo's ESM self-invocation guard compares
    /// import.meta.url (URL-encoded) against file://${process.argv[1]} (raw), and spaces break it.
    static let npmGlobalDir: String = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".duoduo-manager")
            .path
    }()

    /// Bundled node binary path inside the .app bundle
    static let bundledNodePath: String? = {
        Bundle.main.resourceURL?.appendingPathComponent("node/bin/node").path
    }()

    /// Whether bundled Node.js exists
    static var hasBundledNode: Bool {
        guard let path = bundledNodePath else { return false }
        return FileManager.default.isExecutableFile(atPath: path)
    }

    /// Bundled node/bin directory (contains node, npm, npx symlinks)
    static var bundledBinDir: String? {
        bundledNodePath.map { ($0 as NSString).deletingLastPathComponent }
    }

    /// npm bin directory (where duoduo and other global binaries live)
    static let npmBinDir: String = "\(npmGlobalDir)/bin"

    /// duoduo script path
    static let duoduoPath: String = "\(npmBinDir)/duoduo"

    /// duoduo npm package root directory
    static var duoduoPackageDir: String? {
        let path = duoduoPath
        let binDir = (path as NSString).deletingLastPathComponent
        // Resolve symlink: duoduo -> ../lib/node_modules/@openduo/duoduo/bin/duoduo
        let resolved: String
        if let real = try? FileManager.default.destinationOfSymbolicLink(atPath: path) {
            resolved = URL(fileURLWithPath: binDir).appendingPathComponent(real).standardizedFileURL.path
        } else {
            resolved = path
        }
        // resolved is .../duoduo/bin/duoduo, package dir is two levels up
        let packageDir = ((resolved as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent
        return packageDir
    }

    /// Environment variables for subprocess (PATH + NPM_CONFIG_PREFIX + NODE_PATH)
    static var environment: [String: String] {
        var env = ProcessInfo.processInfo.environment

        var paths: [String] = []

        // Bundled node/bin first (contains node, npm, npx)
        if let binDir = bundledBinDir {
            paths.append(binDir)
        }

        // npm global bin (contains duoduo, channel binaries)
        paths.append(npmBinDir)

        // System PATH
        if let existing = env["PATH"] {
            paths.append(contentsOf: existing.components(separatedBy: ":"))
        } else {
            paths.append(contentsOf: ["/usr/local/bin", "/usr/bin", "/bin"])
        }

        env["PATH"] = paths.joined(separator: ":")
        env["NPM_CONFIG_PREFIX"] = npmGlobalDir

        if let bundledDir = Bundle.main.resourceURL?.appendingPathComponent("node").path {
            env["NODE_PATH"] = "\(bundledDir)/lib/node_modules"
        }

        return env
    }

    /// Check if duoduo is installed in our npm global dir
    static var isDuoduoInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: duoduoPath)
    }

    /// Install duoduo via npm into our global dir
    static func installDuoduo() async throws -> String {
        let npmPath = bundledBinDir.map { "\($0)/npm" } ?? "npm"
        return try await ShellService.run(
            npmPath,
            arguments: ["install", "-g", "@openduo/duoduo"],
            environment: environment
        )
    }
}

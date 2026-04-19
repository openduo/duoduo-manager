import Foundation

struct NodeRuntime: Sendable {
    private enum RuntimeMode: String {
        case bundled
        case system
    }

    static let npmGlobalDir: String = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".duoduo-manager")
            .path
    }()

    /// When set, injects NPM_CONFIG_REGISTRY into the environment.
    /// Set to "https://registry.npmmirror.com" for Chinese users.
    static var npmRegistryOverride: String? = nil

    /// Auto-detect whether Chinese locale is in use (defaults mirror preference).
    static var shouldUseMirror: Bool {
        let locales = Locale.preferredLanguages
        return locales.contains { $0.hasPrefix("zh") }
    }

    static let bundledNodePath: String? = {
        Bundle.main.resourceURL?.appendingPathComponent("node/bin/node").path
    }()

    private static var runtimeMode: RuntimeMode {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "DuoduoNodeRuntimeMode") as? String)?
            .lowercased()
        return RuntimeMode(rawValue: raw ?? "") ?? .bundled
    }

    private static var runtime: RuntimeProvider.Type {
        runtimeMode == .bundled ? BundledRuntime.self : SystemRuntime.self
    }

    static var hasBundledNode: Bool { runtime.hasBundledNode }
    static var bundledBinDir: String? { runtime.bundledBinDir }
    static var npmBinDir: String { runtime.npmBinDir }
    static var duoduoPath: String { "duoduo" }
    static var duoduoPackageDir: String? { runtime.duoduoPackageDir }
    static var environment: [String: String] { runtime.environment }
    static var isDuoduoInstalled: Bool { runtime.isDuoduoInstalled }
    static func installDuoduo() async throws -> String { try await runtime.installDuoduo() }

    /// Env vars that callers spawning `duoduo …` should layer onto their
    /// own command-specific env. Currently this is `DUODUO_NODE_BIN`,
    /// which lets the wrapper bypass PATH-based node resolution (see
    /// openduo/duoduo#50). When no bundled node is available (system
    /// runtime), returns an empty dictionary — system mode relies on the
    /// user's own node, which is already on their PATH.
    static var duoduoSpawnEnv: [String: String] {
        guard let nodePath = bundledNodePath, hasBundledNode else { return [:] }
        return [DuoduoCompat.nodeBinEnvVar: nodePath]
    }

    static var hasSystemNode: Bool { SystemRuntime.hasSystemNode }
    static var hasSystemDuoduo: Bool { SystemRuntime.hasSystemDuoduo }

    // MARK: - Shared helpers

    private static func packageDir(fromDuoduoExecutablePath path: String) -> String? {
        let binDir = (path as NSString).deletingLastPathComponent
        let resolved: String
        if let real = try? FileManager.default.destinationOfSymbolicLink(atPath: path) {
            resolved =
                URL(fileURLWithPath: binDir).appendingPathComponent(real).standardizedFileURL.path
        } else {
            resolved = path
        }
        return ((resolved as NSString).deletingLastPathComponent as NSString)
            .deletingLastPathComponent
    }

    private static func mergedSystemPaths(baseEnvironment env: [String: String]) -> [String] {
        var merged = Set(env["PATH"]?.components(separatedBy: ":") ?? [])
        let shell = env["SHELL"] ?? "/bin/zsh"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: shell)
        proc.arguments = ["-l", "-i", "-c", "echo $PATH"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let loginShellPath =
                String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !loginShellPath.isEmpty {
                merged.formUnion(loginShellPath.components(separatedBy: ":"))
            }
        } catch { /* fallback */  }
        return Array(merged).filter { !$0.isEmpty }
    }

    private static func resolveExecutable(named name: String, paths: [String]) -> String? {
        for path in paths {
            let executable = URL(fileURLWithPath: path).appendingPathComponent(name).path
            if FileManager.default.isExecutableFile(atPath: executable) {
                return executable
            }
        }
        return nil
    }

    private protocol RuntimeProvider {
        static var hasBundledNode: Bool { get }
        static var bundledBinDir: String? { get }
        static var npmBinDir: String { get }
        static var duoduoPackageDir: String? { get }
        static var environment: [String: String] { get }
        static var isDuoduoInstalled: Bool { get }
        static func installDuoduo() async throws -> String
    }

    private enum BundledRuntime: RuntimeProvider {
        static var hasBundledNode: Bool {
            guard let path = bundledNodePath else { return false }
            return FileManager.default.isExecutableFile(atPath: path)
        }

        static var bundledBinDir: String? {
            guard hasBundledNode else { return nil }
            return bundledNodePath.map { ($0 as NSString).deletingLastPathComponent }
        }

        static var npmBinDir: String { "\(npmGlobalDir)/bin" }

        static var duoduoPackageDir: String? {
            let path = "\(npmBinDir)/duoduo"
            guard FileManager.default.isExecutableFile(atPath: path) else { return nil }
            return packageDir(fromDuoduoExecutablePath: path)
        }

        static var environment: [String: String] {
            var env = ProcessInfo.processInfo.environment
            var paths: [String] = []
            if let binDir = bundledBinDir {
                paths.append(binDir)
            }
            paths.append(npmBinDir)
            paths.append(contentsOf: mergedSystemPaths(baseEnvironment: env))
            env["PATH"] = paths.joined(separator: ":")
            env["NPM_CONFIG_PREFIX"] = npmGlobalDir
            if let registry = npmRegistryOverride {
                env["NPM_CONFIG_REGISTRY"] = registry
            }
            if hasBundledNode,
                let bundledDir = Bundle.main.resourceURL?.appendingPathComponent("node").path
            {
                env["NODE_PATH"] = "\(bundledDir)/lib/node_modules"
            } else {
                env.removeValue(forKey: "NODE_PATH")
            }
            return env
        }

        static var isDuoduoInstalled: Bool {
            FileManager.default.isExecutableFile(atPath: "\(npmBinDir)/duoduo")
        }

        static func installDuoduo() async throws -> String {
            return try await ShellService.run(
                "npm",
                arguments: ["install", "-g", "@openduo/duoduo"],
                environment: environment
            )
        }
    }

    private enum SystemRuntime: RuntimeProvider {
        static var hasBundledNode: Bool { false }
        static var bundledBinDir: String? { nil }
        static var npmBinDir: String { "" }

        private static var resolvedSystemDuoduoPath: String? {
            resolveExecutable(
                named: "duoduo",
                paths: mergedSystemPaths(baseEnvironment: ProcessInfo.processInfo.environment))
        }

        static var hasSystemNode: Bool {
            resolveExecutable(
                named: "node",
                paths: mergedSystemPaths(baseEnvironment: ProcessInfo.processInfo.environment))
                != nil
        }

        static var hasSystemDuoduo: Bool {
            resolvedSystemDuoduoPath != nil
        }

        static var duoduoPackageDir: String? {
            guard let path = resolvedSystemDuoduoPath else { return nil }
            return packageDir(fromDuoduoExecutablePath: path)
        }

        static var environment: [String: String] {
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = mergedSystemPaths(baseEnvironment: env).joined(separator: ":")
            if let registry = npmRegistryOverride {
                env["NPM_CONFIG_REGISTRY"] = registry
            }
            return env
        }

        static var isDuoduoInstalled: Bool { hasSystemDuoduo }

        static func installDuoduo() async throws -> String {
            try await ShellService.run(
                "npm",
                arguments: ["install", "-g", "@openduo/duoduo"],
                environment: environment
            )
        }
    }
}

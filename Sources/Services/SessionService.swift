import Foundation

struct SessionService: Sendable {
    let daemonURL: String

    init(daemonURL: String) {
        self.daemonURL = daemonURL
    }

    func listAll() async throws -> [SessionRegistryEntry] {
        let output = try await runSession(["list", "--all", "--json"])
        guard let data = output.data(using: .utf8) else { return [] }
        return try JSONDecoder().decode([SessionRegistryEntry].self, from: data)
    }

    func alias(sessionKey: String, name: String?) async throws -> String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var args = ["alias", sessionKey]
        args.append(trimmed.isEmpty ? "--clear" : trimmed)
        return try await runSession(args)
    }

    func notify(target: String, message: String, source: String = "duoduo-atc") async throws -> String {
        try await runSession(["notify", target, "-m", message, "--source", source])
    }

    func archive(sessionKey: String) async throws -> String {
        try await runSession(["archive", sessionKey])
    }

    private func runSession(_ arguments: [String]) async throws -> String {
        try await ShellService.run(
            NodeRuntime.duoduoPath,
            arguments: ["session"] + arguments,
            environment: sessionEnv
        )
    }

    private var sessionEnv: [String: String] {
        var env = NodeRuntime.duoduoSpawnEnv
        env["ALADUO_DAEMON_URL"] = daemonURL
        return env
    }
}

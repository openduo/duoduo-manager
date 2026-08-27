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

    func profileGet(scope: ModelProfileScope) async throws -> ModelProfileSnapshot {
        try await runProfile(ModelProfileCLI.getArguments(scope: scope), scope: scope)
    }

    func profileSet(
        scope: ModelProfileScope,
        modelID: String,
        maxContextTokens: Int,
        baseURL: String?,
        authField: ModelProfileAuthField?,
        authToken: String?
    ) async throws -> ModelProfileSnapshot {
        let args = ModelProfileCLI.setArgumentsJSON(
            scope: scope,
            modelID: modelID,
            maxContextTokens: maxContextTokens,
            baseURL: baseURL,
            authField: authField
        )
        let stdin: Data?
        if authField != nil, let authToken, !authToken.isEmpty {
            stdin = Data(authToken.utf8)
        } else {
            stdin = nil
        }
        return try await runProfile(args, scope: scope, stdin: stdin)
    }

    func profileUnset(scope: ModelProfileScope, modelID: String) async throws -> ModelProfileSnapshot {
        try await runProfile(ModelProfileCLI.unsetArguments(scope: scope, modelID: modelID), scope: scope)
    }

    func profileAliasSet(scope: ModelProfileScope, tier: String, modelID: String) async throws -> ModelProfileSnapshot {
        try await runProfile(
            ModelProfileCLI.aliasSetArguments(scope: scope, tier: tier, modelID: modelID),
            scope: scope
        )
    }

    func profileAliasUnset(scope: ModelProfileScope, tier: String) async throws -> ModelProfileSnapshot {
        try await runProfile(
            ModelProfileCLI.aliasUnsetArguments(scope: scope, tier: tier),
            scope: scope
        )
    }

    private func runSession(_ arguments: [String], stdin: Data? = nil) async throws -> String {
        try await ShellService.run(
            NodeRuntime.duoduoPath,
            arguments: ["session"] + arguments,
            environment: sessionEnv,
            stdin: stdin
        )
    }

    private func runProfile(
        _ arguments: [String],
        scope: ModelProfileScope,
        stdin: Data? = nil
    ) async throws -> ModelProfileSnapshot {
        let output: String
        do {
            output = try await runSession(arguments, stdin: stdin)
        } catch let ShellError.executionFailed(message, _) {
            output = message
        }
        let result: SessionConfigResult
        do {
            result = try SessionConfigJSON.decodeResult(from: output)
        } catch {
            throw ModelProfileError.unreadableOutput
        }
        guard result.ok else {
            throw ModelProfileError.cli(result.failureMessage)
        }
        return result.snapshot(fallbackScope: scope)
    }

    private var sessionEnv: [String: String] {
        var env = NodeRuntime.duoduoSpawnEnv
        env["ALADUO_DAEMON_URL"] = daemonURL
        return env
    }
}

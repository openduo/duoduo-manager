import Foundation

/// Scope for `duoduo session config … profile`. Global is the only layer
/// that also reaches jobs / meta / subconscious. Kind writes
/// `kernel/config/<kind>.md`. Instance (per-session) is intentionally
/// not a manager surface — it lives on the channel descriptor.
enum ModelProfileScope: Hashable, Sendable, Identifiable {
    case global
    case kind(String)

    var id: String {
        switch self {
        case .global: return "global"
        case .kind(let kind): return "kind:\(kind)"
        }
    }

    var cliFlags: [String] {
        switch self {
        case .global:
            return ["--global"]
        case .kind(let kind):
            return ["--kind", kind]
        }
    }
}

enum ModelProfileAuthField: String, Sendable, Hashable, Codable {
    case anthropicAuthToken = "anthropic_auth_token"
    case claudeCodeOAuthToken = "claude_code_oauth_token"

    var stdinFlag: String {
        switch self {
        case .anthropicAuthToken: return "--auth-token-stdin"
        case .claudeCodeOAuthToken: return "--oauth-token-stdin"
        }
    }
}

struct ModelProfileAuth: Decodable, Sendable, Equatable {
    let field: String
    let masked: String

    var typedField: ModelProfileAuthField {
        ModelProfileAuthField(rawValue: field) ?? .anthropicAuthToken
    }
}

struct ModelProfileEntry: Decodable, Sendable, Equatable, Identifiable {
    var id: String { model }
    let model: String
    let max_context_tokens: Int
    let base_url: String?
    let auth: ModelProfileAuth?
    let source: String?

    var isRouted: Bool {
        !(base_url ?? "").isEmpty || auth != nil
    }
}

struct ModelProfileAlias: Decodable, Sendable, Equatable, Identifiable {
    var id: String { tier }
    let tier: String
    let model: String
    let source: String?
}

struct ModelProfileIssue: Decodable, Sendable, Equatable, Identifiable {
    var id: String { "\(layer ?? "-"):\(model ?? "-"):\(reason)" }
    let model: String?
    let reason: String
    let layer: String?
}

struct ModelProfileSettingsConflict: Decodable, Sendable, Equatable {
    let file: String
    let value: String
}

struct ModelProfileAliasWarning: Decodable, Sendable, Equatable {
    let model: String?
    let target_base_url: String?
    let unreachable_from: [String]?
}

/// Wire shape of `duoduo session config … profile … --json`.
struct SessionConfigResult: Decodable, Sendable {
    let ok: Bool
    let verb: String?
    let scope: String?
    let kind: String?
    let reason: String?
    let error: String?
    let errors: [String]?
    let profiles: ModelProfilesPayload?
    let settings_env_conflict: ModelProfileSettingsConflict?
    let alias_endpoint_warning: ModelProfileAliasWarning?

    struct ModelProfilesPayload: Decodable, Sendable {
        let view: String?
        let entries: [ModelProfileEntry]?
        let host_max_context_tokens: Int?
        let aliases: [ModelProfileAlias]?
        let issues: [ModelProfileIssue]?
    }

    var failureMessage: String {
        if let errors, !errors.isEmpty {
            return errors.joined(separator: "\n")
        }
        if let error, !error.isEmpty { return error }
        if let reason, !reason.isEmpty { return reason }
        return "session.config failed"
    }

    func snapshot(fallbackScope: ModelProfileScope) -> ModelProfileSnapshot {
        let resolved: ModelProfileScope
        if scope == "kind", let kind, !kind.isEmpty {
            resolved = .kind(kind)
        } else if scope == "global" {
            resolved = .global
        } else {
            resolved = fallbackScope
        }
        return ModelProfileSnapshot(
            scope: resolved,
            entries: profiles?.entries ?? [],
            aliases: profiles?.aliases ?? [],
            issues: profiles?.issues ?? [],
            hostMaxContextTokens: profiles?.host_max_context_tokens,
            settingsEnvConflict: settings_env_conflict,
            aliasEndpointWarning: alias_endpoint_warning
        )
    }
}

struct ModelProfileSnapshot: Sendable, Equatable {
    var scope: ModelProfileScope
    var entries: [ModelProfileEntry]
    var aliases: [ModelProfileAlias]
    var issues: [ModelProfileIssue]
    var hostMaxContextTokens: Int?
    var settingsEnvConflict: ModelProfileSettingsConflict?
    var aliasEndpointWarning: ModelProfileAliasWarning?

    static let empty = ModelProfileSnapshot(
        scope: .global,
        entries: [],
        aliases: [],
        issues: [],
        hostMaxContextTokens: nil,
        settingsEnvConflict: nil,
        aliasEndpointWarning: nil
    )

    func aliasModel(for tier: String) -> String {
        aliases.first(where: { $0.tier == tier })?.model ?? ""
    }
}

enum ModelProfileCLI {
    static let aliasTiers = ["opus", "sonnet", "haiku", "fable"]

    static func getArguments(scope: ModelProfileScope) -> [String] {
        ["config"] + scope.cliFlags + ["profile", "get", "--json"]
    }

    static func setArguments(
        scope: ModelProfileScope,
        modelID: String,
        maxContextTokens: Int,
        baseURL: String?,
        authField: ModelProfileAuthField?
    ) -> [String] {
        var args = ["config"] + scope.cliFlags + [
            "profile", "set", modelID, String(maxContextTokens)
        ]
        let trimmedURL = baseURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedURL.isEmpty {
            args += ["--base-url", trimmedURL]
        }
        if let authField {
            args.append(authField.stdinFlag)
        }
        return args
    }

    static func unsetArguments(scope: ModelProfileScope, modelID: String) -> [String] {
        ["config"] + scope.cliFlags + ["profile", "unset", modelID, "--json"]
    }

    static func aliasSetArguments(scope: ModelProfileScope, tier: String, modelID: String) -> [String] {
        ["config"] + scope.cliFlags + ["profile", "alias", "set", tier, modelID, "--json"]
    }

    static func aliasUnsetArguments(scope: ModelProfileScope, tier: String) -> [String] {
        ["config"] + scope.cliFlags + ["profile", "alias", "unset", tier, "--json"]
    }

    /// JSON for `--json` profile set lives on stdout even when the CLI
    /// then exits 2. Get already requests `--json`; set does not unless
    /// we add it. Always append `--json` on mutating verbs so the GUI
    /// can refresh from the response.
    static func setArgumentsJSON(
        scope: ModelProfileScope,
        modelID: String,
        maxContextTokens: Int,
        baseURL: String?,
        authField: ModelProfileAuthField?
    ) -> [String] {
        setArguments(
            scope: scope,
            modelID: modelID,
            maxContextTokens: maxContextTokens,
            baseURL: baseURL,
            authField: authField
        ) + ["--json"]
    }
}

enum ModelProfileValidation {
    enum Issue: Equatable {
        case emptyModelID
        case modelIDWhitespace
        case nativeClaudeID
        case oneMSuffix
        case protoKey
        case tokensNotPositive
        case invalidBaseURL
        case baseURLCarriesCredentials
        case routedMissingToken
        case routedMissingBaseURL
        case emptyToken
    }

    static func modelID(_ raw: String) -> Issue? {
        let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if id.isEmpty { return .emptyModelID }
        if id.contains(where: \.isWhitespace) { return .modelIDWhitespace }
        if id.hasPrefix("claude-") { return .nativeClaudeID }
        if id.hasSuffix("[1m]") { return .oneMSuffix }
        if id == "__proto__" { return .protoKey }
        return nil
    }

    static func tokens(_ raw: String) -> (Int, Issue?) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value > 0 else {
            return (0, .tokensNotPositive)
        }
        return (value, nil)
    }

    static func baseURL(_ raw: String) -> Issue? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil
        else {
            return .invalidBaseURL
        }
        if url.user != nil || url.password != nil {
            return .baseURLCarriesCredentials
        }
        return nil
    }
}

struct ModelProfileDraft: Equatable {
    var originalModelID: String?
    var modelID: String
    var tokensText: String
    var routeToEndpoint: Bool
    var baseURL: String
    var authField: ModelProfileAuthField
    var token: String
    var existingAuthMasked: String?

    var isEditing: Bool { originalModelID != nil }

    static func fresh() -> ModelProfileDraft {
        ModelProfileDraft(
            originalModelID: nil,
            modelID: "",
            tokensText: "",
            routeToEndpoint: false,
            baseURL: "",
            authField: .anthropicAuthToken,
            token: "",
            existingAuthMasked: nil
        )
    }

    static func from(_ entry: ModelProfileEntry) -> ModelProfileDraft {
        ModelProfileDraft(
            originalModelID: entry.model,
            modelID: entry.model,
            tokensText: String(entry.max_context_tokens),
            routeToEndpoint: entry.isRouted,
            baseURL: entry.base_url ?? "",
            authField: entry.auth?.typedField ?? .anthropicAuthToken,
            token: "",
            existingAuthMasked: entry.auth?.masked
        )
    }

    /// The CLI `profile set` replaces the whole entry. A routed write
    /// without a token therefore drops credentials — refuse it here.
    func validate() -> [ModelProfileValidation.Issue] {
        var issues: [ModelProfileValidation.Issue] = []
        if let issue = ModelProfileValidation.modelID(modelID) {
            issues.append(issue)
        }
        let tokens = ModelProfileValidation.tokens(tokensText)
        if let issue = tokens.1 {
            issues.append(issue)
        }
        if routeToEndpoint {
            let url = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if url.isEmpty {
                issues.append(.routedMissingBaseURL)
            } else if let issue = ModelProfileValidation.baseURL(url) {
                issues.append(issue)
            }
            let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedToken.isEmpty {
                issues.append(.routedMissingToken)
            }
        }
        return issues
    }

    var parsedTokens: Int {
        ModelProfileValidation.tokens(tokensText).0
    }

    var trimmedModelID: String {
        modelID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBaseURL: String? {
        guard routeToEndpoint else { return nil }
        let url = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return url.isEmpty ? nil : url
    }

    var authInput: (field: ModelProfileAuthField, token: String)? {
        guard routeToEndpoint else { return nil }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return (authField, trimmed)
    }
}

enum ModelProfileError: LocalizedError {
    case unsupportedCLI(installed: String?, minimum: String)
    case daemonNotRunning
    case validation([ModelProfileValidation.Issue])
    case cli(String)
    case unreadableOutput

    var errorDescription: String? {
        switch self {
        case .unsupportedCLI(let installed, let minimum):
            let current = (installed?.isEmpty == false) ? installed! : "?"
            return L10n.ModelProfiles.requiresVersion(minimum, current)
        case .daemonNotRunning:
            return L10n.ModelProfiles.daemonRequired
        case .validation(let issues):
            return issues.map(L10n.ModelProfiles.validationMessage).joined(separator: "\n")
        case .cli(let message):
            return message
        case .unreadableOutput:
            return L10n.ModelProfiles.unreadableOutput
        }
    }
}

enum SessionConfigJSON {
    static func decodeResult(from output: String) throws -> SessionConfigResult {
        let jsonPart = output.components(separatedBy: "\n[stderr]\n").first ?? output
        guard let data = extractJSONObject(from: jsonPart)?.data(using: .utf8) else {
            throw ModelProfileError.unreadableOutput
        }
        return try JSONDecoder().decode(SessionConfigResult.self, from: data)
    }

    static func extractJSONObject(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}")
        else { return nil }
        return String(trimmed[start...end])
    }
}

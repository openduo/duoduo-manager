import Foundation

struct OnboardingStoreDependencies {
    var currentEnv: () throws -> [String: String]
    var detect: (
        _ appStore: AppStore?,
        _ knownClaudeInstalled: Bool?,
        _ knownClaudeVersion: String?,
        _ knownClaudeAuthStatus: ClaudeAuthStatus?
    ) async -> OnboardingSnapshot
    var installDuoduo: () async throws -> String
    var installClaude: () async throws -> Void
    var authStatus: () async throws -> ClaudeAuthStatus
    var login: () async throws -> Void
    var mergeProviderEnv: (_ env: [String: String]) throws -> Void

    static let live = OnboardingStoreDependencies(
        currentEnv: {
            try ClaudeSettingsStore().currentEnv()
        },
        detect: { appStore, knownClaudeInstalled, knownClaudeVersion, knownClaudeAuthStatus in
            await OnboardingService.detect(
                appStore: appStore,
                knownClaudeInstalled: knownClaudeInstalled,
                knownClaudeVersion: knownClaudeVersion,
                knownClaudeAuthStatus: knownClaudeAuthStatus
            )
        },
        installDuoduo: {
            try await NodeRuntime.installDuoduo()
        },
        installClaude: {
            try await ClaudeCLIService.install()
        },
        authStatus: {
            try await ClaudeCLIService.authStatus()
        },
        login: {
            try await ClaudeCLIService.login()
        },
        mergeProviderEnv: { env in
            try ClaudeSettingsStore().mergeEnv(env)
        }
    )
}

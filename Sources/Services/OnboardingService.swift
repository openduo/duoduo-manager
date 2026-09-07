import Foundation

@MainActor
final class OnboardingService {
    static func detect(
        appStore: AppStore? = nil,
        knownClaudeInstalled: Bool? = nil,
        knownClaudeVersion: String? = nil,
        knownClaudeAuthStatus: ClaudeAuthStatus? = nil
    ) async -> OnboardingSnapshot {
        let duoduoInstalled = NodeRuntime.isDuoduoInstalled
        let runtimeStatus = appStore?.runtime.status
        let duoduoVersion = runtimeStatus?.version.nilIfEmpty
        var claudeAuthenticated = knownClaudeAuthStatus?.loggedIn ?? false
        var claudeAuthMethod = knownClaudeAuthStatus?.authMethod
        var claudeAPIProvider = knownClaudeAuthStatus?.apiProvider
        var daemonHealthy = false
        var daemonPID = runtimeStatus?.pid.nilIfEmpty
        let daemonConfig = appStore?.runtime.daemonConfig ?? .load()
        let daemonConfigured = OnboardingCompletionMarker.hasRequiredConfiguration(daemonConfig: daemonConfig)

        if !claudeAuthenticated, let env = try? ClaudeSettingsStore().currentEnv() {
            let token = (env["ANTHROPIC_AUTH_TOKEN"] ?? env["ANTHROPIC_API_KEY"] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty {
                claudeAuthenticated = true
                if claudeAuthMethod == nil {
                    claudeAuthMethod = "api-key"
                }
            }
        }

        if !claudeAuthenticated, knownClaudeAuthStatus == nil {
            if let status = try? await ClaudeCLIService.authStatus() {
                claudeAuthenticated = status.loggedIn
                claudeAuthMethod = status.authMethod
                claudeAPIProvider = status.apiProvider
            }
        }

        if let runtimeStatus {
            daemonHealthy = runtimeStatus.isRunning
            if daemonPID == nil {
                daemonPID = runtimeStatus.pid.nilIfEmpty
            }
        }

        return OnboardingSnapshot(
            duoduoInstalled: duoduoInstalled,
            duoduoVersion: duoduoVersion,
            claudeInstalled: duoduoInstalled,
            claudeVersion: knownClaudeVersion,
            claudeAuthenticated: claudeAuthenticated,
            claudeAuthMethod: claudeAuthMethod,
            claudeAPIProvider: claudeAPIProvider,
            daemonHealthy: daemonHealthy,
            daemonPID: daemonPID,
            daemonConfigured: daemonConfigured
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

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
        var claudeInstalled = knownClaudeInstalled ?? false
        var claudeVersion = knownClaudeVersion
        var claudeAuthenticated = knownClaudeAuthStatus?.loggedIn ?? false
        var claudeAuthMethod = knownClaudeAuthStatus?.authMethod
        var claudeAPIProvider = knownClaudeAuthStatus?.apiProvider
        var daemonHealthy = false
        var daemonPID = runtimeStatus?.pid.nilIfEmpty
        let daemonConfig = appStore?.runtime.daemonConfig ?? .load()
        let daemonConfigured = OnboardingCompletionMarker.hasRequiredConfiguration(daemonConfig: daemonConfig)

        if knownClaudeInstalled == nil || knownClaudeVersion == nil || knownClaudeAuthStatus == nil {
            do {
                if let knownClaudeInstalled {
                    claudeInstalled = knownClaudeInstalled
                } else {
                    claudeInstalled = try await ClaudeCLIService.isInstalled()
                }
                if claudeInstalled {
                    if let knownClaudeVersion {
                        claudeVersion = knownClaudeVersion
                    } else {
                        claudeVersion = try await ClaudeCLIService.version()
                    }
                    if knownClaudeAuthStatus == nil {
                        let auth = try await ClaudeCLIService.authStatus()
                        claudeAuthenticated = auth.loggedIn
                        claudeAuthMethod = auth.authMethod
                        claudeAPIProvider = auth.apiProvider
                    }
                }
            } catch { }
        } else if let knownClaudeAuthStatus {
            claudeAuthenticated = knownClaudeAuthStatus.loggedIn
            claudeAuthMethod = knownClaudeAuthStatus.authMethod
            claudeAPIProvider = knownClaudeAuthStatus.apiProvider
            claudeInstalled = knownClaudeInstalled ?? true
            if claudeVersion == nil, claudeInstalled {
                do {
                    claudeVersion = try await ClaudeCLIService.version()
                } catch { }
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
            claudeInstalled: claudeInstalled,
            claudeVersion: claudeVersion,
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

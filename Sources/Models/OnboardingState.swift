import Foundation

enum OnboardingRequirement: String, CaseIterable, Identifiable, Hashable {
    case duoduoCLI
    case claudeCLI
    case claudeAccess
    case daemon

    var id: String { rawValue }

    var title: String {
        switch self {
        case .duoduoCLI:
            return L10n.Onboard.reqDuoduoCLI
        case .claudeCLI:
            return L10n.Onboard.reqClaudeCLI
        case .claudeAccess:
            return L10n.Onboard.reqClaudeAccess
        case .daemon:
            return L10n.Onboard.reqDaemon
        }
    }

    var icon: String {
        switch self {
        case .duoduoCLI:
            return "shippingbox.fill"
        case .claudeCLI:
            return "terminal.fill"
        case .claudeAccess:
            return "key.radiowaves.forward.fill"
        case .daemon:
            return "play.circle.fill"
        }
    }

    var summary: String {
        switch self {
        case .duoduoCLI:
            return L10n.Onboard.summaryDuoduoCLI
        case .claudeCLI:
            return L10n.Onboard.summaryClaudeCLI
        case .claudeAccess:
            return L10n.Onboard.summaryClaudeAccess
        case .daemon:
            return L10n.Onboard.summaryDaemon
        }
    }
}

struct OnboardingSnapshot {
    var duoduoInstalled: Bool
    var duoduoVersion: String?
    var claudeInstalled: Bool
    var claudeVersion: String?
    var claudeAuthenticated: Bool
    var claudeAuthMethod: String?
    var claudeAPIProvider: String?
    var daemonHealthy: Bool
    var daemonPID: String?

    static let empty = OnboardingSnapshot(
        duoduoInstalled: false,
        duoduoVersion: nil,
        claudeInstalled: false,
        claudeVersion: nil,
        claudeAuthenticated: false,
        claudeAuthMethod: nil,
        claudeAPIProvider: nil,
        daemonHealthy: false,
        daemonPID: nil
    )

    var unmetRequirements: [OnboardingRequirement] {
        var requirements: [OnboardingRequirement] = []
        if !duoduoInstalled {
            requirements.append(.duoduoCLI)
        }
        if !claudeInstalled {
            requirements.append(.claudeCLI)
        }
        if claudeInstalled && !claudeAuthenticated {
            requirements.append(.claudeAccess)
        }
        if !daemonHealthy {
            requirements.append(.daemon)
        }
        return requirements
    }
}

struct OnboardingState {
    enum Step: Equatable {
        case detecting
        case ready
        case complete
    }

    var step: Step = .detecting
    var snapshot: OnboardingSnapshot = .empty
    var currentRequirement: OnboardingRequirement?
    var statusMessage: String?
    var errorMessage: String?
    var isBusy = false
    var useNpmMirror = NodeRuntime.shouldUseMirror
    var selectedPreset: LLMProviderPreset = .official
    var authToken = ""
    var customBaseURL = ""
    var customModel = ""
    var showSecret = false
    var hydratedSettings = false
    var preferredRequirement: OnboardingRequirement?

    var visibleRequirements: [OnboardingRequirement] {
        let requirements = snapshot.unmetRequirements
        if requirements.isEmpty, let currentRequirement {
            return [currentRequirement]
        }
        return requirements
    }

    var canSaveProvider: Bool {
        if selectedPreset == .official { return true }
        let tokenFilled = !authToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if selectedPreset == .custom {
            return tokenFilled && !customBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return tokenFilled
    }
}

enum OnboardingEvent {
    case bootstrap
    case refreshRequested
    case editRequirementRequested(OnboardingRequirement)
    case settingsHydrated([String: String])
    case hydrateSettingsFailed(String)
    case useMirrorChanged(Bool)
    case providerPresetChanged(LLMProviderPreset)
    case authTokenChanged(String)
    case customBaseURLChanged(String)
    case customModelChanged(String)
    case showSecretToggled
    case installDuoduoRequested
    case installClaudeRequested
    case verifyClaudeStatusRequested
    case saveProviderRequested
    case oauthLoginRequested
    case startDaemonRequested
    case detectionFinished(OnboardingSnapshot, status: String?)
    case operationFailed(String)
}

enum OnboardingCommand: Equatable {
    case hydrateSettings
    case detect(status: String)
    case installDuoduo(useMirror: Bool)
    case installClaude(useMirror: Bool)
    case verifyClaudeStatus
    case saveProviderConfig(envVars: [String: String], successStatus: String)
    case performOAuthLogin
    case startDaemon
}

enum OnboardingReducer {
    static func reduce(state: inout OnboardingState, event: OnboardingEvent) -> OnboardingCommand? {
        switch event {
        case .bootstrap:
            return state.hydratedSettings ? startDetection(state: &state, status: L10n.Onboard.statusDetecting) : .hydrateSettings

        case .refreshRequested:
            return startDetection(state: &state, status: L10n.Onboard.statusRedetecting)

        case .editRequirementRequested(let requirement):
            state.preferredRequirement = requirement
            state.currentRequirement = requirement
            state.step = .ready
            state.isBusy = false
            state.errorMessage = nil
            state.statusMessage = L10n.Onboard.statusEditing(requirement.title)
            return nil

        case .settingsHydrated(let env):
            state.hydratedSettings = true
            hydrate(state: &state, env: env)
            return startDetection(state: &state, status: L10n.Onboard.statusDetecting)

        case .hydrateSettingsFailed(let message):
            state.hydratedSettings = true
            state.errorMessage = message
            return startDetection(state: &state, status: L10n.Onboard.statusDetecting)

        case .useMirrorChanged(let value):
            state.useNpmMirror = value
            return nil

        case .providerPresetChanged(let preset):
            state.selectedPreset = preset
            if preset != .custom {
                state.customBaseURL = preset.envVars["ANTHROPIC_BASE_URL"] ?? ""
                state.customModel = preset.envVars["ANTHROPIC_MODEL"] ?? ""
            }
            clearMessages(state: &state)
            return nil

        case .authTokenChanged(let value):
            state.authToken = value
            return nil

        case .customBaseURLChanged(let value):
            state.customBaseURL = value
            return nil

        case .customModelChanged(let value):
            state.customModel = value
            return nil

        case .showSecretToggled:
            state.showSecret.toggle()
            return nil

        case .installDuoduoRequested:
            guard !state.isBusy else { return nil }
            beginBusy(state: &state, message: L10n.Onboard.statusInstallingDuoduo)
            return .installDuoduo(useMirror: state.useNpmMirror)

        case .installClaudeRequested:
            guard !state.isBusy else { return nil }
            beginBusy(state: &state, message: L10n.Onboard.statusInstallingClaude)
            return .installClaude(useMirror: state.useNpmMirror)

        case .verifyClaudeStatusRequested:
            guard !state.isBusy else { return nil }
            beginBusy(state: &state, message: L10n.Onboard.statusReadingAuth)
            return .verifyClaudeStatus

        case .saveProviderRequested:
            guard !state.isBusy, state.canSaveProvider else { return nil }
            beginBusy(state: &state, message: L10n.Onboard.statusWritingSettings)
            return .saveProviderConfig(
                envVars: providerEnvVars(from: state),
                successStatus: L10n.Onboard.statusProviderSaved
            )

        case .oauthLoginRequested:
            guard !state.isBusy else { return nil }
            beginBusy(state: &state, message: L10n.Onboard.statusBrowserLogin)
            return .performOAuthLogin

        case .startDaemonRequested:
            guard !state.isBusy else { return nil }
            beginBusy(state: &state, message: L10n.Onboard.statusStartingDaemon)
            return .startDaemon

        case .detectionFinished(let snapshot, let status):
            state.snapshot = snapshot
            if snapshot.unmetRequirements.isEmpty {
                state.currentRequirement = state.preferredRequirement
                state.step = .complete
            } else {
                state.currentRequirement = snapshot.unmetRequirements.first
                state.step = .ready
            }
            state.isBusy = false
            state.errorMessage = nil
            if let status {
                state.statusMessage = status
            } else if snapshot.unmetRequirements.isEmpty {
                state.statusMessage = L10n.Onboard.statusSystemReady
            } else if let requirement = state.currentRequirement {
                state.statusMessage = L10n.Onboard.statusNext(requirement.title)
            }
            return nil

        case .operationFailed(let message):
            state.isBusy = false
            state.errorMessage = message
            return nil
        }
    }

    private static func hydrate(state: inout OnboardingState, env: [String: String]) {
        state.authToken = env["ANTHROPIC_AUTH_TOKEN"] ?? env["ANTHROPIC_API_KEY"] ?? ""
        state.customBaseURL = env["ANTHROPIC_BASE_URL"] ?? ""
        state.customModel = env["ANTHROPIC_MODEL"] ?? ""

        if let matchedPreset = LLMProviderPreset.allPresets().first(where: {
            $0 != .custom && $0.envVars["ANTHROPIC_BASE_URL"] == state.customBaseURL
        }) {
            state.selectedPreset = matchedPreset
        } else if !state.customBaseURL.isEmpty {
            state.selectedPreset = .custom
        }
    }

    private static func providerEnvVars(from state: OnboardingState) -> [String: String] {
        var envVars = state.selectedPreset.envVars
        if state.selectedPreset == .custom {
            envVars["ANTHROPIC_BASE_URL"] = state.customBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedModel = state.customModel.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedModel.isEmpty {
                envVars["ANTHROPIC_MODEL"] = trimmedModel
            }
        }
        envVars["ANTHROPIC_AUTH_TOKEN"] = state.authToken.trimmingCharacters(in: .whitespacesAndNewlines)
        return envVars
    }

    private static func startDetection(state: inout OnboardingState, status: String) -> OnboardingCommand {
        state.isBusy = true
        state.step = .detecting
        state.errorMessage = nil
        state.statusMessage = status
        return .detect(status: status)
    }

    private static func beginBusy(state: inout OnboardingState, message: String) {
        state.isBusy = true
        clearMessages(state: &state)
        state.statusMessage = message
    }

    private static func clearMessages(state: inout OnboardingState) {
        state.statusMessage = nil
        state.errorMessage = nil
    }
}

@MainActor
@Observable
final class OnboardingStore {
    private let appStore: AppStore?
    private let dependencies: OnboardingStoreDependencies
    var state = OnboardingState()

    init(
        appStore: AppStore? = nil,
        preferredRequirement: OnboardingRequirement? = nil,
        dependencies: OnboardingStoreDependencies = .live
    ) {
        self.appStore = appStore
        self.dependencies = dependencies
        state.preferredRequirement = preferredRequirement
    }

    func send(_ event: OnboardingEvent) {
        guard let command = OnboardingReducer.reduce(state: &state, event: event) else { return }
        Task { await run(command) }
    }

    func run(_ command: OnboardingCommand) async {
        switch command {
        case .hydrateSettings:
            do {
                let env = try dependencies.currentEnv()
                send(.settingsHydrated(env))
            } catch {
                send(.hydrateSettingsFailed(error.localizedDescription))
            }

        case .detect(let status):
            if let appStore {
                await appStore.refreshRuntime()
            }
            let snapshot = await dependencies.detect(appStore, nil, nil, nil)
            send(.detectionFinished(snapshot, status: status))

        case .installDuoduo(let useMirror):
            do {
                _ = try await dependencies.installDuoduo(useMirror)
                send(.refreshRequested)
            } catch {
                send(.operationFailed(error.localizedDescription))
            }

        case .installClaude(let useMirror):
            do {
                try await dependencies.installClaude(useMirror)
                send(.refreshRequested)
            } catch {
                send(.operationFailed(error.localizedDescription))
            }

        case .verifyClaudeStatus:
            do {
                let status = try await dependencies.authStatus()
                if status.loggedIn {
                    let snapshot = await dependencies.detect(appStore, true, nil, status)
                    send(.detectionFinished(snapshot, status: L10n.Onboard.statusLlmVerified))
                } else {
                    send(.operationFailed(L10n.Onboard.errAuthNotVerified))
                }
            } catch {
                send(.operationFailed(error.localizedDescription))
            }

        case .saveProviderConfig(let envVars, let successStatus):
            do {
                try dependencies.mergeProviderEnv(envVars)
                let status = try await dependencies.authStatus()
                if status.loggedIn {
                    let snapshot = await dependencies.detect(appStore, true, nil, status)
                    send(.detectionFinished(snapshot, status: successStatus))
                } else {
                    send(.operationFailed(L10n.Onboard.errConfigSavedButAuthFailed))
                }
            } catch {
                send(.operationFailed(error.localizedDescription))
            }

        case .performOAuthLogin:
            do {
                try await dependencies.login()
                let authStatus = try await dependencies.authStatus()
                if authStatus.loggedIn {
                    let snapshot = await dependencies.detect(appStore, true, nil, authStatus)
                    send(.detectionFinished(snapshot, status: L10n.Onboard.statusLoginSuccess))
                } else {
                    send(.operationFailed(L10n.Onboard.errBrowserLoginIncomplete))
                }
            } catch {
                send(.operationFailed(error.localizedDescription))
            }

        case .startDaemon:
            do {
                if let appStore {
                    _ = try await appStore.daemonService.start(extraEnv: [:])
                    await appStore.refreshRuntime()

                    if appStore.runtime.status.isRunning {
                        let snapshot = await dependencies.detect(appStore, nil, nil, nil)
                        send(.detectionFinished(snapshot, status: L10n.Onboard.statusDaemonStarted))
                    } else {
                        send(.operationFailed(L10n.Onboard.errDaemonNotHealthy))
                    }
                } else {
                    send(.operationFailed(L10n.Onboard.errDaemonNotHealthy))
                }
            } catch {
                send(.operationFailed(error.localizedDescription))
            }
        }
    }
}

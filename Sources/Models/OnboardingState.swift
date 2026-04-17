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
            return "安装 duoduo"
        case .claudeCLI:
            return "安装 Claude CLI"
        case .claudeAccess:
            return "连接 LLM"
        case .daemon:
            return "启动 daemon"
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
            return "把 manager 需要的 duoduo CLI 安装到当前运行环境。"
        case .claudeCLI:
            return "安装 claude 命令行工具，后续认证和 provider 配置都依赖它。"
        case .claudeAccess:
            return "使用浏览器登录或写入 ~/.claude/settings.json，让 `claude auth status` 通过。"
        case .daemon:
            return "启动 duoduo daemon，让菜单栏主界面可以继续管理运行时。"
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

enum OnboardingCommand {
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
            return state.hydratedSettings ? startDetection(state: &state, status: "正在读取 duoduo、claude 和 daemon 状态。") : .hydrateSettings

        case .refreshRequested:
            return startDetection(state: &state, status: "正在重新读取本机状态。")

        case .editRequirementRequested(let requirement):
            state.preferredRequirement = requirement
            state.currentRequirement = requirement
            state.step = .ready
            state.isBusy = false
            state.errorMessage = nil
            state.statusMessage = "继续修改\(requirement.title)。"
            return nil

        case .settingsHydrated(let env):
            state.hydratedSettings = true
            hydrate(state: &state, env: env)
            return startDetection(state: &state, status: "正在读取 duoduo、claude 和 daemon 状态。")

        case .hydrateSettingsFailed(let message):
            state.hydratedSettings = true
            state.errorMessage = message
            return startDetection(state: &state, status: "正在读取 duoduo、claude 和 daemon 状态。")

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
            beginBusy(state: &state, message: "正在安装 duoduo CLI。")
            return .installDuoduo(useMirror: state.useNpmMirror)

        case .installClaudeRequested:
            guard !state.isBusy else { return nil }
            beginBusy(state: &state, message: "正在安装 Claude CLI。")
            return .installClaude(useMirror: state.useNpmMirror)

        case .verifyClaudeStatusRequested:
            guard !state.isBusy else { return nil }
            beginBusy(state: &state, message: "正在读取 `claude auth status`。")
            return .verifyClaudeStatus

        case .saveProviderRequested:
            guard !state.isBusy, state.canSaveProvider else { return nil }
            beginBusy(state: &state, message: "正在写入 ~/.claude/settings.json。")
            return .saveProviderConfig(
                envVars: providerEnvVars(from: state),
                successStatus: "provider 配置已生效，正在继续。"
            )

        case .oauthLoginRequested:
            guard !state.isBusy else { return nil }
            beginBusy(state: &state, message: "正在打开浏览器登录...")
            return .performOAuthLogin

        case .startDaemonRequested:
            guard !state.isBusy else { return nil }
            beginBusy(state: &state, message: "正在启动 duoduo daemon。")
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
                state.statusMessage = "系统已经就绪。"
            } else if let requirement = state.currentRequirement {
                state.statusMessage = "下一步：\(requirement.title)"
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
    var state = OnboardingState()

    init(appStore: AppStore? = nil, preferredRequirement: OnboardingRequirement? = nil) {
        self.appStore = appStore
        state.preferredRequirement = preferredRequirement
    }

    func send(_ event: OnboardingEvent) {
        guard let command = OnboardingReducer.reduce(state: &state, event: event) else { return }
        Task { await run(command) }
    }

    private func run(_ command: OnboardingCommand) async {
        switch command {
        case .hydrateSettings:
            do {
                let env = try ClaudeSettingsStore().currentEnv()
                send(.settingsHydrated(env))
            } catch {
                send(.hydrateSettingsFailed(error.localizedDescription))
            }

        case .detect(let status):
            if let appStore {
                await appStore.refreshRuntime()
            }
            let snapshot = await OnboardingService.detect(appStore: appStore)
            send(.detectionFinished(snapshot, status: status))

        case .installDuoduo(let useMirror):
            let previousRegistry = NodeRuntime.npmRegistryOverride
            if useMirror {
                NodeRuntime.npmRegistryOverride = "https://registry.npmmirror.com"
            }
            defer {
                NodeRuntime.npmRegistryOverride = previousRegistry
            }

            do {
                _ = try await NodeRuntime.installDuoduo()
                send(.refreshRequested)
            } catch {
                send(.operationFailed(error.localizedDescription))
            }

        case .installClaude(let useMirror):
            do {
                try await ClaudeCLIService.install(useMirror: useMirror)
                send(.refreshRequested)
            } catch {
                send(.operationFailed(error.localizedDescription))
            }

        case .verifyClaudeStatus:
            do {
                let status = try await ClaudeCLIService.authStatus()
                if status.loggedIn {
                    let snapshot = await OnboardingService.detect(
                        appStore: appStore,
                        knownClaudeInstalled: true,
                        knownClaudeAuthStatus: status
                    )
                    send(.detectionFinished(snapshot, status: "LLM 连接已验证，正在继续。"))
                } else {
                    send(.operationFailed("尚未通过 `claude auth status` 校验。"))
                }
            } catch {
                send(.operationFailed(error.localizedDescription))
            }

        case .saveProviderConfig(let envVars, let successStatus):
            do {
                try ClaudeSettingsStore().mergeEnv(envVars)
                let status = try await ClaudeCLIService.authStatus()
                if status.loggedIn {
                    let snapshot = await OnboardingService.detect(
                        appStore: appStore,
                        knownClaudeInstalled: true,
                        knownClaudeAuthStatus: status
                    )
                    send(.detectionFinished(snapshot, status: successStatus))
                } else {
                    send(.operationFailed("配置已写入，但 `claude auth status` 仍未通过。请检查 Base URL、Token 或模型配置。"))
                }
            } catch {
                send(.operationFailed(error.localizedDescription))
            }

        case .performOAuthLogin:
            do {
                try await ClaudeCLIService.login()
                let authStatus = try await ClaudeCLIService.authStatus()
                if authStatus.loggedIn {
                    let snapshot = await OnboardingService.detect(
                        appStore: appStore,
                        knownClaudeInstalled: true,
                        knownClaudeAuthStatus: authStatus
                    )
                    send(.detectionFinished(snapshot, status: "登录成功，正在继续。"))
                } else {
                    send(.operationFailed("浏览器登录未完成，请重试。"))
                }
            } catch {
                send(.operationFailed(error.localizedDescription))
            }

        case .startDaemon:
            let config = DaemonConfig.load()
            let service = DaemonService(daemonURL: config.daemonURL)

            do {
                _ = try await service.start(extraEnv: config.envVars)
                let status = try await service.getStatus()
                if status.isRunning {
                    if let appStore {
                        await appStore.refreshRuntime()
                    }
                    let snapshot = await OnboardingService.detect(appStore: appStore)
                    send(.detectionFinished(snapshot, status: "daemon 已启动，正在重新检测。"))
                } else {
                    send(.operationFailed("daemon 未进入 healthy 状态。"))
                }
            } catch {
                send(.operationFailed(error.localizedDescription))
            }
        }
    }
}

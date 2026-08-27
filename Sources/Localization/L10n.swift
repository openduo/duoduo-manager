import Foundation

// swiftlint:disable line_length

/// Type-safe localization keys. Uses `String(localized:bundle:)` for lookups.
/// The bundle falls back to `Bundle.module` (SPM-processed resources) when
/// running via `swift run`, and `Bundle.main` when running from an `.app` bundle.
enum L10n {
    /// Bundle resolution: try `Bundle.main` first (`.app`), fall back to `Bundle.module` (SPM).
    static let bundle: Bundle = {
        if Bundle.main.url(forResource: "en", withExtension: "lproj") != nil {
            return Bundle.main
        }

        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle.main
        #endif
    }()

    // MARK: - Status

    enum Status {
        static let running = String(localized: "status.running", bundle: bundle)
        static let stopped = String(localized: "status.stopped", bundle: bundle)
        static let hasUpdate = String(localized: "status.hasUpdate", bundle: bundle)
        static func appUpdate(_ version: String) -> String {
            String(localized: "status.appUpdate \(version)", bundle: bundle)
        }
        static let configure = String(localized: "status.configure", bundle: bundle)
        static let install = String(localized: "status.install", bundle: bundle)
        static let updateAll = String(localized: "status.updateAll", bundle: bundle)
        static let updatingAll = String(localized: "status.updatingAll", bundle: bundle)
        static let clear = String(localized: "status.clear", bundle: bundle)
        static let quit = String(localized: "status.quit", bundle: bundle)
    }

    // MARK: - Config

    enum Config {
        static let save = String(localized: "config.save", bundle: bundle)
        static let saved = String(localized: "config.saved", bundle: bundle)
        static let cancel = String(localized: "config.cancel", bundle: bundle)
        static let enabled = String(localized: "config.enabled", bundle: bundle)
        static let disabled = String(localized: "config.disabled", bundle: bundle)
    }

    // MARK: - Model Profiles

    enum ModelProfiles {
        static let title = String(localized: "modelProfiles.title", bundle: bundle)
        static let windowTitle = String(localized: "modelProfiles.windowTitle", bundle: bundle)
        static let footerButton = String(localized: "modelProfiles.footerButton", bundle: bundle)
        static let subtitle = String(localized: "modelProfiles.subtitle", bundle: bundle)
        static let layer = String(localized: "modelProfiles.layer", bundle: bundle)
        static let scopeGlobal = String(localized: "modelProfiles.scopeGlobal", bundle: bundle)
        static let scopeGlobalDetail = String(localized: "modelProfiles.scopeGlobalDetail", bundle: bundle)
        static func scopeKindDetail(_ kind: String) -> String {
            String(localized: "modelProfiles.scopeKindDetail \(kind)", bundle: bundle)
        }
        static let profilesSection = String(localized: "modelProfiles.profilesSection", bundle: bundle)
        static let aliasesSection = String(localized: "modelProfiles.aliasesSection", bundle: bundle)
        static let add = String(localized: "modelProfiles.add", bundle: bundle)
        static let edit = String(localized: "modelProfiles.edit", bundle: bundle)
        static let remove = String(localized: "modelProfiles.remove", bundle: bundle)
        static let refresh = String(localized: "modelProfiles.refresh", bundle: bundle)
        static let empty = String(localized: "modelProfiles.empty", bundle: bundle)
        static let modelID = String(localized: "modelProfiles.modelID", bundle: bundle)
        static let modelIDHint = String(localized: "modelProfiles.modelIDHint", bundle: bundle)
        static let windowTokens = String(localized: "modelProfiles.windowTokens", bundle: bundle)
        static let windowTokensHint = String(localized: "modelProfiles.windowTokensHint", bundle: bundle)
        static let routeToggle = String(localized: "modelProfiles.routeToggle", bundle: bundle)
        static let routeHint = String(localized: "modelProfiles.routeHint", bundle: bundle)
        static let baseURL = String(localized: "modelProfiles.baseURL", bundle: bundle)
        static let baseURLPlaceholder = String(localized: "modelProfiles.baseURLPlaceholder", bundle: bundle)
        static let credential = String(localized: "modelProfiles.credential", bundle: bundle)
        static let authToken = String(localized: "modelProfiles.authToken", bundle: bundle)
        static let oauthToken = String(localized: "modelProfiles.oauthToken", bundle: bundle)
        static let token = String(localized: "modelProfiles.token", bundle: bundle)
        static let tokenRequiredAgain = String(localized: "modelProfiles.tokenRequiredAgain", bundle: bundle)
        static let existingToken = String(localized: "modelProfiles.existingToken", bundle: bundle)
        static let hostEndpoint = String(localized: "modelProfiles.hostEndpoint", bundle: bundle)
        static let rebuildNote = String(localized: "modelProfiles.rebuildNote", bundle: bundle)
        static let aliasesHint = String(localized: "modelProfiles.aliasesHint", bundle: bundle)
        static let aliasPlaceholder = String(localized: "modelProfiles.aliasPlaceholder", bundle: bundle)
        static let aliasClear = String(localized: "modelProfiles.aliasClear", bundle: bundle)
        static let aliasSaved = String(localized: "modelProfiles.aliasSaved", bundle: bundle)
        static let saved = String(localized: "modelProfiles.saved", bundle: bundle)
        static let editorAddTitle = String(localized: "modelProfiles.editorAddTitle", bundle: bundle)
        static let editorEditTitle = String(localized: "modelProfiles.editorEditTitle", bundle: bundle)
        static let deleteTitle = String(localized: "modelProfiles.deleteTitle", bundle: bundle)
        static func deleteMessage(_ model: String) -> String {
            String(localized: "modelProfiles.deleteMessage \(model)", bundle: bundle)
        }
        static let daemonRequired = String(localized: "modelProfiles.daemonRequired", bundle: bundle)
        static let unreadableOutput = String(localized: "modelProfiles.unreadableOutput", bundle: bundle)
        static func requiresVersion(_ minimum: String, _ installed: String) -> String {
            String(localized: "modelProfiles.requiresVersion \(minimum) \(installed)", bundle: bundle)
        }
        static func tokenCount(_ formatted: String) -> String {
            String(localized: "modelProfiles.tokenCount \(formatted)", bundle: bundle)
        }
        static func removed(_ model: String) -> String {
            String(localized: "modelProfiles.removed \(model)", bundle: bundle)
        }
        static func rejectedEntry(_ model: String, _ reason: String, _ layer: String) -> String {
            String(localized: "modelProfiles.rejectedEntry \(model) \(reason) \(layer)", bundle: bundle)
        }
        static func settingsConflict(_ file: String, _ value: String) -> String {
            String(localized: "modelProfiles.settingsConflict \(file) \(value)", bundle: bundle)
        }
        static func aliasEndpointWarning(_ model: String, _ endpoint: String) -> String {
            String(localized: "modelProfiles.aliasEndpointWarning \(model) \(endpoint)", bundle: bundle)
        }
        static func validationMessage(_ issue: ModelProfileValidation.Issue) -> String {
            switch issue {
            case .emptyModelID:
                return String(localized: "modelProfiles.validation.emptyModelID", bundle: bundle)
            case .modelIDWhitespace:
                return String(localized: "modelProfiles.validation.modelIDWhitespace", bundle: bundle)
            case .nativeClaudeID:
                return String(localized: "modelProfiles.validation.nativeClaudeID", bundle: bundle)
            case .oneMSuffix:
                return String(localized: "modelProfiles.validation.oneMSuffix", bundle: bundle)
            case .protoKey:
                return String(localized: "modelProfiles.validation.protoKey", bundle: bundle)
            case .tokensNotPositive:
                return String(localized: "modelProfiles.validation.tokensNotPositive", bundle: bundle)
            case .invalidBaseURL:
                return String(localized: "modelProfiles.validation.invalidBaseURL", bundle: bundle)
            case .baseURLCarriesCredentials:
                return String(localized: "modelProfiles.validation.baseURLCarriesCredentials", bundle: bundle)
            case .routedMissingToken:
                return String(localized: "modelProfiles.validation.routedMissingToken", bundle: bundle)
            case .routedMissingBaseURL:
                return String(localized: "modelProfiles.validation.routedMissingBaseURL", bundle: bundle)
            case .emptyToken:
                return String(localized: "modelProfiles.validation.emptyToken", bundle: bundle)
            }
        }
        static let columnModel = String(localized: "modelProfiles.columnModel", bundle: bundle)
        static let columnWindow = String(localized: "modelProfiles.columnWindow", bundle: bundle)
        static let columnEndpoint = String(localized: "modelProfiles.columnEndpoint", bundle: bundle)
        static let columnAuth = String(localized: "modelProfiles.columnAuth", bundle: bundle)
        static let claudeOnly = String(localized: "modelProfiles.claudeOnly", bundle: bundle)
    }

    // MARK: - Daemon Config

    enum DaemonConfig {
        static let title = String(localized: "daemonConfig.title", bundle: bundle)
        static let workDir = String(localized: "daemonConfig.workDir", bundle: bundle)
        static let workDirHint = String(localized: "daemonConfig.workDirHint", bundle: bundle)
        static let workDirSelect = String(localized: "daemonConfig.workDirSelect", bundle: bundle)
        static let workDirPanelMessage = String(localized: "daemonConfig.workDirPanelMessage", bundle: bundle)
        static let network = String(localized: "daemonConfig.network", bundle: bundle)
        static let general = String(localized: "daemonConfig.general", bundle: bundle)
        static let daemonHost = String(localized: "daemonConfig.daemonHost", bundle: bundle)
        static let listenPort = String(localized: "daemonConfig.listenPort", bundle: bundle)
        static let logging = String(localized: "daemonConfig.logging", bundle: bundle)
        static let logLevel = String(localized: "daemonConfig.logLevel", bundle: bundle)
        static let permissions = String(localized: "daemonConfig.permissions", bundle: bundle)
        static let permissionMode = String(localized: "daemonConfig.permissionMode", bundle: bundle)
        static let session = String(localized: "daemonConfig.session", bundle: bundle)
        static let maxConcurrent = String(localized: "daemonConfig.maxConcurrent", bundle: bundle)
        static let advancedSettings = String(localized: "daemonConfig.advancedSettings", bundle: bundle)
        static let idleTimeout = String(localized: "daemonConfig.idleTimeout", bundle: bundle)
        static let idleTimeoutHint = String(localized: "daemonConfig.idleTimeoutHint", bundle: bundle)
        static let disableAutoMain = String(localized: "daemonConfig.disableAutoMain", bundle: bundle)
        static let autoMainDisabled = String(localized: "daemonConfig.autoMainDisabled", bundle: bundle)
        static let autoMainDefault = String(localized: "daemonConfig.autoMainDefault", bundle: bundle)
        static let pullLimit = String(localized: "daemonConfig.pullLimit", bundle: bundle)
        static let remoteAccess = String(localized: "daemonConfig.remoteAccess", bundle: bundle)
        static let remotePort = String(localized: "daemonConfig.remotePort", bundle: bundle)
        static let remotePortHint = String(localized: "daemonConfig.remotePortHint", bundle: bundle)
        static let remotePortPlaceholder = String(localized: "daemonConfig.remotePortPlaceholder", bundle: bundle)
        static let daemonToken = String(localized: "daemonConfig.daemonToken", bundle: bundle)
        static let daemonTokenHint = String(localized: "daemonConfig.daemonTokenHint", bundle: bundle)
        static let daemonTokenNew = String(localized: "daemonConfig.daemonTokenNew", bundle: bundle)
        static let daemonTokenRotate = String(localized: "daemonConfig.daemonTokenRotate", bundle: bundle)
        static let daemonTokenGenerated = String(localized: "daemonConfig.daemonTokenGenerated", bundle: bundle)
        static let remoteHostWarning = String(localized: "daemonConfig.remoteHostWarning", bundle: bundle)
        static let remoteRequiresRestart = String(localized: "daemonConfig.remoteRequiresRestart", bundle: bundle)
        static func remotePortCollision(_ readOnlyPort: String) -> String {
            String(localized: "daemonConfig.remotePortCollision \(readOnlyPort)", bundle: bundle)
        }
    }

    // MARK: - Feishu Config

    enum FeishuConfig {
        static let title = String(localized: "feishuConfig.title", bundle: bundle)
        static let auth = String(localized: "feishuConfig.auth", bundle: bundle)
        static let appID = String(localized: "feishuConfig.appID", bundle: bundle)
        static let appSecret = String(localized: "feishuConfig.appSecret", bundle: bundle)
        static let connection = String(localized: "feishuConfig.connection", bundle: bundle)
        static let feishuDomain = String(localized: "feishuConfig.feishuDomain", bundle: bundle)
        static let accessControl = String(localized: "feishuConfig.accessControl", bundle: bundle)
        static let dmPolicy = String(localized: "feishuConfig.dmPolicy", bundle: bundle)
        static let dmPolicyOpen = String(localized: "feishuConfig.dmPolicyOpen", bundle: bundle)
        static let dmPolicyAllowlist = String(localized: "feishuConfig.dmPolicyAllowlist", bundle: bundle)
        static let groupPolicy = String(localized: "feishuConfig.groupPolicy", bundle: bundle)
        static let requireMention = String(localized: "feishuConfig.requireMention", bundle: bundle)
        static let requireMentionOn = String(localized: "feishuConfig.requireMentionOn", bundle: bundle)
        static let requireMentionOff = String(localized: "feishuConfig.requireMentionOff", bundle: bundle)
        static let allowedUsers = String(localized: "feishuConfig.allowedUsers", bundle: bundle)
        static let allowedGroups = String(localized: "feishuConfig.allowedGroups", bundle: bundle)
        static let render = String(localized: "feishuConfig.render", bundle: bundle)
        static let renderMode = String(localized: "feishuConfig.renderMode", bundle: bundle)
        static let renderModeDescAuto = String(localized: "feishuConfig.renderModeDescAuto", bundle: bundle)
        static let renderModeDescRaw = String(localized: "feishuConfig.renderModeDescRaw", bundle: bundle)
        static let renderModeDescCard = String(localized: "feishuConfig.renderModeDescCard", bundle: bundle)
        static let advancedSettings = String(localized: "feishuConfig.advancedSettings", bundle: bundle)
        static let botOpenId = String(localized: "feishuConfig.botOpenId", bundle: bundle)
        static let logLevel = String(localized: "feishuConfig.logLevel", bundle: bundle)
    }

    // MARK: - Channel

    enum Channel {
        static let feishuDisplayName = String(localized: "channel.feishuDisplayName", bundle: bundle)
        static let feishuConfigHint = String(localized: "channel.feishuConfigHint", bundle: bundle)
        static let feishuConfigRequired = String(localized: "channel.feishuConfigRequired", bundle: bundle)
    }

    // MARK: - Dashboard

    enum Dashboard {
        static let activeSessionsHeader = String(localized: "dashboard.activeSessionsHeader", bundle: bundle)
        static let sessionsTitle = String(localized: "dashboard.sessionsTitle", bundle: bundle)
        static let noSessions = String(localized: "dashboard.noSessions", bundle: bundle)
        static let workSessions = String(localized: "dashboard.workSessions", bundle: bundle)
        static let jobSessions = String(localized: "dashboard.jobSessions", bundle: bundle)
        static let metaSessions = String(localized: "dashboard.metaSessions", bundle: bundle)
        static let alias = String(localized: "dashboard.alias", bundle: bundle)
        static let notify = String(localized: "dashboard.notify", bundle: bundle)
        static let archive = String(localized: "dashboard.archive", bundle: bundle)
        static let archiveSessionTitle = String(localized: "dashboard.archiveSessionTitle", bundle: bundle)
        static let sessionAliasTitle = String(localized: "dashboard.sessionAliasTitle", bundle: bundle)
        static let displayNamePlaceholder = String(localized: "dashboard.displayNamePlaceholder", bundle: bundle)
        static let clearAlias = String(localized: "dashboard.clearAlias", bundle: bundle)
        static let notifySessionTitle = String(localized: "dashboard.notifySessionTitle", bundle: bundle)
        static let send = String(localized: "dashboard.send", bundle: bundle)
    }

    // MARK: - Error (with interpolation)

    enum Error {
        static func executionFailed(_ message: String) -> String {
            String(localized: "error.executionFailed \(message)", bundle: bundle)
        }
        static func commandNotFound(_ cmd: String) -> String {
            String(localized: "error.commandNotFound \(cmd)", bundle: bundle)
        }
        static func prefix(_ message: String) -> String {
            String(localized: "error.prefix \(message)", bundle: bundle)
        }
    }

    // MARK: - Upgrade

    enum Upgrade {
        static let allUpToDate = String(localized: "upgrade.allUpToDate", bundle: bundle)
        static let updatingHeader = String(localized: "upgrade.updatingHeader", bundle: bundle)
        static func updatingCount(_ count: Int) -> String {
            String(localized: "upgrade.updatingCount", defaultValue: "Updating \(count) component(s)…", bundle: bundle)
        }
    }

    // MARK: - Setup

    enum Setup {
        static let installingDuoduo = String(localized: "setup.installingDuoduo", bundle: bundle)
        static let installSuccess = String(localized: "setup.installSuccess", bundle: bundle)
        static let installFailed = String(localized: "setup.installFailed", bundle: bundle)
        static let systemNodeMissingTitle = String(localized: "setup.systemNodeMissingTitle", bundle: bundle)
        static let systemNodeMissing = String(localized: "setup.systemNodeMissing", bundle: bundle)
    }

    // MARK: - Onboard

    enum Onboard {
        static let headerTitle = String(localized: "onboard.headerTitle", bundle: bundle)
        static let setupComplete = String(localized: "onboard.setupComplete", bundle: bundle)
        static let enjoy = String(localized: "onboard.enjoy", bundle: bundle)
        static let readyHint = String(localized: "onboard.readyHint", bundle: bundle)
        static let editConfig = String(localized: "onboard.editConfig", bundle: bundle)
        static let close = String(localized: "onboard.close", bundle: bundle)
        static let detecting = String(localized: "onboard.detecting", bundle: bundle)
        static let installing = String(localized: "onboard.installing", bundle: bundle)
        static let starting = String(localized: "onboard.starting", bundle: bundle)
        static let waiting = String(localized: "onboard.waiting", bundle: bundle)
        static let connected = String(localized: "onboard.connected", bundle: bundle)
        static let needToken = String(localized: "onboard.needToken", bundle: bundle)
        static let tokenPlaceholder = String(localized: "onboard.tokenPlaceholder", bundle: bundle)
        static let baseUrlPlaceholder = String(localized: "onboard.baseUrlPlaceholder", bundle: bundle)
        static let modelPlaceholder = String(localized: "onboard.modelPlaceholder", bundle: bundle)
        static let continue_ = String(localized: "onboard.continue", bundle: bundle)
        static let saving = String(localized: "onboard.saving", bundle: bundle)
        static let verify = String(localized: "onboard.verify", bundle: bundle)
        static let browserLogin = String(localized: "onboard.browserLogin", bundle: bundle)
        static let waitingLogin = String(localized: "onboard.waitingLogin", bundle: bundle)
        static let officialHint = String(localized: "onboard.officialHint", bundle: bundle)
        static let workDirPrompt = String(localized: "onboard.workDirPrompt", bundle: bundle)
        static let startDaemon = String(localized: "onboard.startDaemon", bundle: bundle)
        static let customProvider = String(localized: "onboard.customProvider", bundle: bundle)
        static let createBot = String(localized: "onboard.createBot", bundle: bundle)
        static func update(_ version: String) -> String {
            String(localized: "onboard.update \(version)", bundle: bundle)
        }
        static let metricModel = String(localized: "onboard.metricModel", bundle: bundle)

        // Requirement titles
        static let reqDuoduoCLI = String(localized: "onboard.req.duoduoCLI", bundle: bundle)
        static let reqClaudeCLI = String(localized: "onboard.req.claudeCLI", bundle: bundle)
        static let reqClaudeAccess = String(localized: "onboard.req.claudeAccess", bundle: bundle)
        static let reqDaemon = String(localized: "onboard.req.daemon", bundle: bundle)

        // Requirement summaries
        static let summaryDuoduoCLI = String(localized: "onboard.summary.duoduoCLI", bundle: bundle)
        static let summaryClaudeCLI = String(localized: "onboard.summary.claudeCLI", bundle: bundle)
        static let summaryClaudeAccess = String(localized: "onboard.summary.claudeAccess", bundle: bundle)
        static let summaryDaemon = String(localized: "onboard.summary.daemon", bundle: bundle)

        // Status messages
        static let statusDetecting = String(localized: "onboard.status.detecting", bundle: bundle)
        static let statusRedetecting = String(localized: "onboard.status.redetecting", bundle: bundle)
        static func statusEditing(_ title: String) -> String {
            String(localized: "onboard.status.editing \(title)", bundle: bundle)
        }
        static let statusInstallingDuoduo = String(localized: "onboard.status.installingDuoduo", bundle: bundle)
        static let statusInstallingClaude = String(localized: "onboard.status.installingClaude", bundle: bundle)
        static let statusReadingAuth = String(localized: "onboard.status.readingAuth", bundle: bundle)
        static let statusWritingSettings = String(localized: "onboard.status.writingSettings", bundle: bundle)
        static let statusProviderSaved = String(localized: "onboard.status.providerSaved", bundle: bundle)
        static let statusBrowserLogin = String(localized: "onboard.status.browserLogin", bundle: bundle)
        static let statusStartingDaemon = String(localized: "onboard.status.startingDaemon", bundle: bundle)
        static let statusSystemReady = String(localized: "onboard.status.systemReady", bundle: bundle)
        static func statusNext(_ title: String) -> String {
            String(localized: "onboard.status.next \(title)", bundle: bundle)
        }
        static let statusLoginSuccess = String(localized: "onboard.status.loginSuccess", bundle: bundle)
        static let statusDaemonStarted = String(localized: "onboard.status.daemonStarted", bundle: bundle)
        static let statusLlmVerified = String(localized: "onboard.status.llmVerified", bundle: bundle)

        // Error messages
        static let errClaudeNotInstalled = String(localized: "onboard.error.claudeNotInstalled", bundle: bundle)
        static let errLoginTimeout = String(localized: "onboard.error.loginTimeout", bundle: bundle)
        static let errSettingsInvalid = String(localized: "onboard.error.settingsInvalid", bundle: bundle)
        static let errAuthOutputParse = String(localized: "onboard.error.authOutputParse", bundle: bundle)
        static let errAuthNotVerified = String(localized: "onboard.error.authNotVerified", bundle: bundle)
        static let errConfigSavedButAuthFailed = String(localized: "onboard.error.configSavedButAuthFailed", bundle: bundle)
        static let errBrowserLoginIncomplete = String(localized: "onboard.error.browserLoginIncomplete", bundle: bundle)
        static let errDaemonNotHealthy = String(localized: "onboard.error.daemonNotHealthy", bundle: bundle)

        // Agent shell PATH (post-completion enhancement)
        enum ShellPath {
            static let title = String(localized: "onboard.shellPath.title", bundle: bundle)
            static let summary = String(localized: "onboard.shellPath.summary", bundle: bundle)
            static let summaryFailed = String(localized: "onboard.shellPath.summaryFailed", bundle: bundle)
            static let autoRepairFailed = String(localized: "onboard.shellPath.autoRepairFailed", bundle: bundle)
            static let stateNeedsManualAction = String(localized: "onboard.shellPath.stateNeedsManualAction", bundle: bundle)
            static func gateRequiresUpgrade(_ minVersion: String) -> String {
                String(localized: "onboard.shellPath.gateRequiresUpgrade \(minVersion)", bundle: bundle)
            }
            static let gateRequiresInstall = String(localized: "onboard.shellPath.gateRequiresInstall", bundle: bundle)
        }
    }

}

// swiftlint:enable line_length

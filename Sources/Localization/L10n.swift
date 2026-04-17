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
        static let clear = String(localized: "status.clear", bundle: bundle)
        static let quit = String(localized: "status.quit", bundle: bundle)
        static let terminal = String(localized: "status.terminal", bundle: bundle)
    }

    // MARK: - Config

    enum Config {
        static let save = String(localized: "config.save", bundle: bundle)
        static let cancel = String(localized: "config.cancel", bundle: bundle)
    }

    // MARK: - Daemon Config

    enum DaemonConfig {
        static let title = String(localized: "daemonConfig.title", bundle: bundle)
        static let workDir = String(localized: "daemonConfig.workDir", bundle: bundle)
        static let workDirHint = String(localized: "daemonConfig.workDirHint", bundle: bundle)
        static let workDirSelect = String(localized: "daemonConfig.workDirSelect", bundle: bundle)
        static let workDirPanelMessage = String(localized: "daemonConfig.workDirPanelMessage", bundle: bundle)
        static let network = String(localized: "daemonConfig.network", bundle: bundle)
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
    }

    // MARK: - Feishu Config

    enum FeishuConfig {
        static let title = String(localized: "feishuConfig.title", bundle: bundle)
        static let auth = String(localized: "feishuConfig.auth", bundle: bundle)
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
    }

}

// swiftlint:enable line_length

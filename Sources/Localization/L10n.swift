import Foundation

// swiftlint:disable line_length

/// Type-safe localization keys. Uses `String(localized:bundle:)` for lookups.
/// The bundle falls back to `Bundle.module` (SPM-processed resources) when
/// running via `swift run`, and `Bundle.main` when running from an `.app` bundle.
enum L10n {
    /// Bundle resolution: try `Bundle.main` first (`.app`), fall back to `Bundle.module` (SPM).
    static let bundle: Bundle = Bundle.main.url(forResource: "en", withExtension: "lproj") != nil
        ? Bundle.main : Bundle.module

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
    }

    // MARK: - Config

    enum Config {
        static let save = String(localized: "config.save", bundle: bundle)
    }

    // MARK: - Claude Config

    enum ClaudeConfig {
        static let title = String(localized: "claudeConfig.title", bundle: bundle)
        static let actions = String(localized: "claudeConfig.actions", bundle: bundle)
        static let tabBasic = String(localized: "claudeConfig.tabBasic", bundle: bundle)
        static let tabAdvanced = String(localized: "claudeConfig.tabAdvanced", bundle: bundle)
        static let flowSwitch = String(localized: "claudeConfig.flowSwitch", bundle: bundle)
        static let flowCreate = String(localized: "claudeConfig.flowCreate", bundle: bundle)
        static let presets = String(localized: "claudeConfig.presets", bundle: bundle)
        static let newPreset = String(localized: "claudeConfig.newPreset", bundle: bundle)
        static let newPresetName = String(localized: "claudeConfig.newPresetName", bundle: bundle)
        static let createPresetAction = String(localized: "claudeConfig.createPresetAction", bundle: bundle)
        static let deletePreset = String(localized: "claudeConfig.deletePreset", bundle: bundle)
        static let presetName = String(localized: "claudeConfig.presetName", bundle: bundle)
        static let commonFields = String(localized: "claudeConfig.commonFields", bundle: bundle)
        static let modelGroup = String(localized: "claudeConfig.modelGroup", bundle: bundle)
        static let finalJSON = String(localized: "claudeConfig.finalJSON", bundle: bundle)
        static let applyToFile = String(localized: "claudeConfig.applyToFile", bundle: bundle)
        static let pathLabel = String(localized: "claudeConfig.pathLabel", bundle: bundle)
        static let lastStatus = String(localized: "claudeConfig.lastStatus", bundle: bundle)
        static let localSaved = String(localized: "claudeConfig.localSaved", bundle: bundle)
        static let applied = String(localized: "claudeConfig.applied", bundle: bundle)
        static let savedShort = String(localized: "claudeConfig.savedShort", bundle: bundle)
        static let appliedShort = String(localized: "claudeConfig.appliedShort", bundle: bundle)
        static let saving = String(localized: "claudeConfig.saving", bundle: bundle)
        static let applying = String(localized: "claudeConfig.applying", bundle: bundle)
        static let saveFailed = String(localized: "claudeConfig.saveFailed", bundle: bundle)
        static let applyFailed = String(localized: "claudeConfig.applyFailed", bundle: bundle)
        static let exportPresets = String(localized: "claudeConfig.exportPresets", bundle: bundle)
        static let importPresets = String(localized: "claudeConfig.importPresets", bundle: bundle)
        static let exportHint = String(localized: "claudeConfig.exportHint", bundle: bundle)
        static let importHint = String(localized: "claudeConfig.importHint", bundle: bundle)
        static let exported = String(localized: "claudeConfig.exported", bundle: bundle)
        static let imported = String(localized: "claudeConfig.imported", bundle: bundle)
        static let importEmpty = String(localized: "claudeConfig.importEmpty", bundle: bundle)
        static let invalidJSON = String(localized: "claudeConfig.invalidJSON", bundle: bundle)
        static let newFromTemplate = String(localized: "claudeConfig.newFromTemplate", bundle: bundle)
        static let advancedToggle = String(localized: "claudeConfig.advancedToggle", bundle: bundle)
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

}

// swiftlint:enable line_length

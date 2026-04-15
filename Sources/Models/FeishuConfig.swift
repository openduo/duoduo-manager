import Foundation

/// Feishu channel configuration, mapped to @openduo/channel-feishu environment variables
struct FeishuConfig: Codable, Sendable, Equatable {

    // MARK: - Authentication (required)

    var appId: String = ""
    var appSecret: String = ""

    // MARK: - Connection
    /// feishu · lark · or custom domain URL
    var domain: String = "feishu"

    // MARK: - Access Control
    /// open | allowlist
    var dmPolicy: String = "open"
    /// open | allowlist | disabled
    var groupPolicy: String = "allowlist"
    var requireMention: Bool = true
    /// Comma-separated open_id allowlist
    var allowFrom: String = ""
    /// Comma-separated chat_id allowlist
    var allowGroups: String = ""

    // MARK: - Rendering
    /// auto | raw | card
    var renderMode: String = "auto"

    // MARK: - Advanced

    var botOpenId: String = ""
    /// debug | info | warn | error
    var logLevel: String = "info"

    // MARK: - Helpers

    var isConfigured: Bool {
        !appId.trimmingCharacters(in: .whitespaces).isEmpty &&
        !appSecret.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Environment variables injected into `duoduo channel feishu start`
    var envVars: [String: String] {
        var env: [String: String] = [:]
        env["FEISHU_APP_ID"]          = appId
        env["FEISHU_APP_SECRET"]      = appSecret
        if !domain.isEmpty            { env["FEISHU_DOMAIN"] = domain }
        env["FEISHU_DM_POLICY"]       = dmPolicy
        env["FEISHU_GROUP_POLICY"]    = groupPolicy
        env["FEISHU_REQUIRE_MENTION"] = requireMention ? "true" : "false"
        if !allowFrom.isEmpty         { env["FEISHU_ALLOW_FROM"] = allowFrom }
        if !allowGroups.isEmpty       { env["FEISHU_ALLOW_GROUPS"] = allowGroups }
        env["FEISHU_RENDER_MODE"]     = renderMode
        if !botOpenId.isEmpty         { env["FEISHU_BOT_OPEN_ID"] = botOpenId }
        env["FEISHU_LOG_LEVEL"]       = logLevel
        return env
    }

    // MARK: - Persistence

    private static let udKey = "feishu_channel_config_v1"

    static func load() -> FeishuConfig {
        ConfigStore.load(defaultValue: FeishuConfig(), forKey: udKey)
    }

    func save() {
        ConfigStore.save(self, forKey: FeishuConfig.udKey)
    }
}

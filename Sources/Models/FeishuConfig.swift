import Foundation

struct FeishuConfig: Sendable, Equatable {
    var appId: String = ""
    var appSecret: String = ""
    var domain: String = "feishu"
    var dmPolicy: String = "open"
    var groupPolicy: String = "open"
    var requireMention: Bool = true
    var allowFrom: String = ""
    var allowGroups: String = ""

    var isConfigured: Bool {
        !appId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !appSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func load() -> FeishuConfig {
        let values = ConfigStore.loadValues()
        var config = FeishuConfig()
        config.appId = values["FEISHU_APP_ID"] ?? config.appId
        config.appSecret = values["FEISHU_APP_SECRET"] ?? config.appSecret
        config.domain = values["FEISHU_DOMAIN"] ?? config.domain
        config.dmPolicy = values["FEISHU_DM_POLICY"] ?? config.dmPolicy
        config.groupPolicy = values["FEISHU_GROUP_POLICY"] ?? config.groupPolicy
        config.requireMention = boolValue(values["FEISHU_REQUIRE_MENTION"], default: config.requireMention)
        config.allowFrom = normalizedList(values["FEISHU_ALLOW_FROM"])
        config.allowGroups = normalizedList(values["FEISHU_ALLOW_GROUPS"])
        return config
    }

    func save() {
        ConfigStore.save(entries: persistedEntries, managedKeys: Self.managedKeys)
    }

    var persistedEntries: [(key: String, value: String)] {
        var entries: [(String, String)] = []
        appendIfNonEmpty(&entries, "FEISHU_APP_ID", appId)
        appendIfNonEmpty(&entries, "FEISHU_APP_SECRET", appSecret)
        appendIfDifferent(&entries, "FEISHU_DOMAIN", domain, defaultValue: "feishu")
        appendIfDifferent(&entries, "FEISHU_DM_POLICY", dmPolicy, defaultValue: "open")
        appendIfDifferent(&entries, "FEISHU_GROUP_POLICY", groupPolicy, defaultValue: "open")
        appendIfDifferent(&entries, "FEISHU_REQUIRE_MENTION", requireMention, defaultValue: true)
        appendIfNonEmpty(&entries, "FEISHU_ALLOW_FROM", normalizedList(allowFrom))
        appendIfNonEmpty(&entries, "FEISHU_ALLOW_GROUPS", normalizedList(allowGroups))
        return entries
    }

    private static let managedKeys: Set<String> = [
        "FEISHU_APP_ID",
        "FEISHU_APP_SECRET",
        "FEISHU_DOMAIN",
        "FEISHU_DM_POLICY",
        "FEISHU_GROUP_POLICY",
        "FEISHU_REQUIRE_MENTION",
        "FEISHU_ALLOW_FROM",
        "FEISHU_ALLOW_GROUPS",
    ]
}

private func normalizedList(_ rawValue: String?) -> String {
    guard let rawValue else { return "" }
    return rawValue
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: ",")
}

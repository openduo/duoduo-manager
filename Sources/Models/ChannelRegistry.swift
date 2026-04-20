import Foundation

struct ChannelEntry: Identifiable, Sendable {
    let id: String                        // channel type, e.g. "feishu"
    let displayName: String               // e.g. "Feishu"
    let packageName: String               // e.g. "@openduo/channel-feishu"
    let iconName: String                  // SF Symbol name

    init(
        id: String,
        displayName: String,
        packageName: String,
        iconName: String
    ) {
        self.id = id
        self.displayName = displayName
        self.packageName = packageName
        self.iconName = iconName
    }
}

enum ChannelRegistry {
    /// Generate channel list based on configured channels
    static func channels(feishuConfig: FeishuConfig) -> [ChannelEntry] {
        [
            ChannelEntry(
                id: "feishu",
                displayName: L10n.Channel.feishuDisplayName,
                packageName: "@openduo/channel-feishu",
                iconName: "message.badge.waveform.fill"
            ),
        ]
    }

    static func entry(for type: String, feishuConfig: FeishuConfig) -> ChannelEntry? {
        channels(feishuConfig: feishuConfig).first { $0.id == type }
    }
}

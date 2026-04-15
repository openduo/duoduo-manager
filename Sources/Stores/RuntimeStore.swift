import Foundation

@MainActor
@Observable
final class RuntimeStore {
    var status: DaemonStatus
    var channels: [ChannelInfo]
    var daemonConfig: DaemonConfig
    var feishuConfig: FeishuConfig
    var isSettingUp: Bool

    init(
        status: DaemonStatus = .empty,
        channels: [ChannelInfo] = [],
        daemonConfig: DaemonConfig = .load(),
        feishuConfig: FeishuConfig = .load(),
        isSettingUp: Bool = false
    ) {
        self.status = status
        self.channels = channels
        self.daemonConfig = daemonConfig
        self.feishuConfig = feishuConfig
        self.isSettingUp = isSettingUp
    }
}

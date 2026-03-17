import Foundation

struct ChannelInfo: Sendable, Identifiable, Equatable {
    static func == (lhs: ChannelInfo, rhs: ChannelInfo) -> Bool {
        lhs.type == rhs.type && lhs.version == rhs.version
            && lhs.isRunning == rhs.isRunning && lhs.pid == rhs.pid
    }
    let id = UUID()
    let type: String
    var version: String
    var isRunning: Bool
    var pid: String = ""

    var displayName: String {
        ChannelRegistry.entry(for: type, feishuConfig: FeishuConfig())?.displayName ?? type.capitalized
    }

    var icon: String {
        ChannelRegistry.entry(for: type, feishuConfig: FeishuConfig())?.iconName ?? "antenna.radiowaves.left.and.right"
    }
}

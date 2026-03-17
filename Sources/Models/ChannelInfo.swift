import Foundation

struct ChannelInfo: Sendable, Identifiable, Equatable {
    static func == (lhs: ChannelInfo, rhs: ChannelInfo) -> Bool {
        lhs.type == rhs.type && lhs.version == rhs.version
            && lhs.latestVersion == rhs.latestVersion && lhs.isRunning == rhs.isRunning
            && lhs.pid == rhs.pid
    }
    let id = UUID()
    let type: String
    var version: String
    var latestVersion: String = ""
    var isRunning: Bool
    var pid: String = ""

    var displayName: String {
        ChannelRegistry.entry(for: type, feishuConfig: FeishuConfig())?.displayName ?? type.capitalized
    }

    var icon: String {
        ChannelRegistry.entry(for: type, feishuConfig: FeishuConfig())?.iconName ?? "antenna.radiowaves.left.and.right"
    }

    var hasUpdate: Bool {
        guard !version.isEmpty, !latestVersion.isEmpty else { return false }
        return version.compare(latestVersion, options: .numeric) == .orderedAscending
    }
}

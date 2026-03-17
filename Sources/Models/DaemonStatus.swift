import Foundation

struct DaemonStatus: Sendable, Equatable {
    var isRunning: Bool = false
    var version: String = ""
    var latestVersion: String = ""
    var pid: String = ""
    var output: String = ""
    var lastUpdated: Date = .distantPast

    static let empty = DaemonStatus()

    var hasUpdate: Bool {
        guard !version.isEmpty, !latestVersion.isEmpty else { return false }
        return version.compare(latestVersion, options: .numeric) == .orderedAscending
    }
}

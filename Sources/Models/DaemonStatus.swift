import Foundation

struct DaemonStatus: Sendable, Equatable {
    var isRunning: Bool = false
    var version: String = ""
    var pid: String = ""
    var output: String = ""
    var daemonConfigValues: [String: String] = [:]
    var lastUpdated: Date = .distantPast

    static let empty = DaemonStatus()
}

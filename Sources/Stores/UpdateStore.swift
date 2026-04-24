import Foundation

@MainActor
@Observable
final class UpdateStore {
    var latestVersions: [String: String]
    var appLatestVersion: String?

    init(
        latestVersions: [String: String] = [:],
        appLatestVersion: String? = nil
    ) {
        self.latestVersions = latestVersions
        self.appLatestVersion = appLatestVersion
    }
}

import Foundation

@MainActor
@Observable
final class UpdateStore {
    var latestVersions: [String: String]
    var appLatestVersion: String?
    var appLatestReleaseURL: URL?

    init(
        latestVersions: [String: String] = [:],
        appLatestVersion: String? = nil,
        appLatestReleaseURL: URL? = nil
    ) {
        self.latestVersions = latestVersions
        self.appLatestVersion = appLatestVersion
        self.appLatestReleaseURL = appLatestReleaseURL
    }
}

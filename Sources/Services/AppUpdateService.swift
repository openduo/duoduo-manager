import AppKit

struct AppUpdateService: Sendable {

    /// GitHub owner/repo for release checking
    private static let owner = "openduo"
    private static let repo = "duoduo-manager"

    /// Current app version from Info.plist
    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    /// Check GitHub Releases API for the latest non-draft, non-prerelease tag.
    /// Returns the version string (e.g. "0.7.0") or nil on failure.
    func fetchLatestReleaseVersion() async -> String? {
        guard let result = await fetchLatestRelease() else { return nil }
        return result.version
    }

    /// Returns both the version and the release page URL for the latest release.
    func fetchLatestRelease() async -> (version: String, url: URL)? {
        let url = URL(string: "https://api.github.com/repos/\(Self.owner)/\(Self.repo)/releases/latest")!
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        // Unauthenticated requests are rate-limited to 60/hour — sufficient for periodic checks.

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String
            else { return nil }
            // Strip leading "v" if present
            let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            let htmlURL = URL(string: "https://github.com/\(Self.owner)/\(Self.repo)/releases/tag/\(tagName)")
            return (version: version, url: htmlURL ?? URL(string: "https://github.com/\(Self.owner)/\(Self.repo)/releases")!)
        } catch {
            return nil
        }
    }

    /// Open the releases page in the default browser.
    static func openReleasesPage() {
        let url = URL(string: "https://github.com/\(owner)/\(repo)/releases")!
        NSWorkspace.shared.open(url)
    }
}

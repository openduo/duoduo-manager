import Foundation

struct VersionService: Sendable {

    // MARK: - GitHub Releases

    /// Query the latest GitHub release tag. `repo` like "duoduo" or "channel-feishu"
    func checkLatestVersion(repo: String) async -> String? {
        guard let url = URL(string: "https://api.github.com/repos/openduo/\(repo)/releases/latest")
        else { return nil }
        do {
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200
            else { return nil }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let tagName = json?["tag_name"] as? String {
                return tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            }
        } catch {}
        return nil
    }

    // MARK: - npm

    func getInstalledVersion(_ pkg: String) async throws -> String? {
        let output = try await ShellService.runShell(
            "npm list -g \(pkg) --depth=0 2>/dev/null | grep '\(pkg)' | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+' || true"
        )
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func getNpmLatestVersion(_ pkg: String) async throws -> String {
        let output = try await ShellService.runShell(
            "npm view \(pkg) version 2>/dev/null || echo 'unknown'"
        )
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

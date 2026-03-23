import Foundation

struct VersionService: Sendable {

    func getInstalledVersion(_ pkg: String) async throws -> String? {
        let npmPath = NodeRuntime.bundledBinDir.map { "\($0)/npm" } ?? "npm"
        let output = try await ShellService.run(
            npmPath,
            arguments: ["list", "-g", pkg, "--depth=0", "--json"]
        )
        // Parse json output for version
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let deps = json["dependencies"] as? [String: Any],
              let pkgInfo = deps[pkg] as? [String: Any],
              let version = pkgInfo["version"] as? String
        else { return nil }
        return version
    }

    func getNpmLatestVersion(_ pkg: String) async throws -> String {
        let npmPath = NodeRuntime.bundledBinDir.map { "\($0)/npm" } ?? "npm"
        let output = try await ShellService.run(
            npmPath,
            arguments: ["view", pkg, "version"]
        )
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

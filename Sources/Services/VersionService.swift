import Foundation

struct VersionService: Sendable {

    func getInstalledVersion(_ pkg: String) async throws -> String? {
        let output = try await ShellService.run(
            "npm",
            arguments: ["list", "-g", pkg, "--depth=0", "--json"],
            environment: NodeRuntime.environment
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
        let output = try await ShellService.run(
            "npm",
            arguments: ["view", pkg, "version"],
            environment: NodeRuntime.environment
        )
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

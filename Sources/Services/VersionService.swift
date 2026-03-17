import Foundation

struct VersionService: Sendable {

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

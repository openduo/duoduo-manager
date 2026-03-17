import Foundation

struct UpgradeService: Sendable {
    private let versionService = VersionService()
    let npmPackages = ["@openduo/duoduo"]

    func checkVersions() async throws -> [PackageVersion] {
        var versions: [PackageVersion] = []

        for pkg in npmPackages {
            let installed = try await versionService.getInstalledVersion(pkg)
            let latest = try await versionService.getNpmLatestVersion(pkg)
            versions.append(PackageVersion(
                name: pkg,
                installedVersion: installed,
                latestVersion: latest,
                needsUpdate: installed != latest && installed != nil
            ))
        }

        return versions
    }

    func upgrade(packages: [String]) async throws -> String {
        var output = ""
        for pkg in packages {
            output += try await ShellService.runShell("npm install -g \(pkg)@latest")
        }
        return output
    }

    /// Update all components: daemon + channels with new versions
    /// - Parameters:
    ///   - channels: currently installed channel list
    ///   - extraEnv: closure to get extra env for a channel type
    ///   - installChannel: closure to install a channel package
    ///   - startChannel: closure to start a channel (channel type + extraEnv)
    func upgradeAll(
        channels: [ChannelInfo],
        extraEnv: (String) -> [String: String],
        installChannel: (String) async throws -> String,
        startChannel: (String, [String: String]) async throws -> String
    ) async throws -> String {
        var output = ""

        // 1. Update daemon
        let versions = try await checkVersions()
        let toUpgrade = versions.filter { $0.needsUpdate }.map { $0.name }
        if !toUpgrade.isEmpty {
            output += try await upgrade(packages: toUpgrade)
        }

        // 2. Only update channels with new versions, record pre-update state for restore
        for channel in channels {
            guard channel.hasUpdate else { continue }
            let wasRunning = channel.isRunning
            let pkg = ChannelRegistry.entry(for: channel.type, feishuConfig: FeishuConfig())?.packageName
                ?? "@openduo/channel-\(channel.type)"
            output += try await installChannel(pkg)
            if wasRunning {
                output += try await startChannel(channel.type, extraEnv(channel.type))
            }
        }

        if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            output = L10n.Upgrade.allUpToDate
        }

        return output
    }
}

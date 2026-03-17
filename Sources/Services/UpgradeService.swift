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
            print("[DuoduoManager] npm install -g \(pkg)@latest")
            let result = try await ShellService.runShell("npm install -g \(pkg)@latest")
            print("[DuoduoManager] npm result: \(result)")
            output += result
        }
        return output
    }

    /// Update all components: daemon + all channels
    /// - Parameters:
    ///   - channels: currently installed channel list
    ///   - extraEnv: closure to get extra env for a channel type
    ///   - syncChannel: closure to sync a channel (duoduo channel install)
    ///   - startChannel: closure to start a channel (channel type + extraEnv)
    func upgradeAll(
        channels: [ChannelInfo],
        extraEnv: (String) -> [String: String],
        syncChannel: (String) async throws -> String,
        startChannel: (String, [String: String]) async throws -> String
    ) async throws -> String {
        var output = ""

        // 1. Always update daemon to latest
        output += try await upgrade(packages: npmPackages)

        // 2. Always sync all channels, record pre-update state for restore
        for channel in channels {
            print("[DuoduoManager] syncing channel: \(channel.type)")
            let wasRunning = channel.isRunning
            let pkg = ChannelRegistry.entry(for: channel.type, feishuConfig: FeishuConfig())?.packageName
                ?? "@openduo/channel-\(channel.type)"
            let syncResult = try await syncChannel(pkg)
            print("[DuoduoManager] channel sync result: \(syncResult)")
            output += syncResult
            if wasRunning {
                output += try await startChannel(channel.type, extraEnv(channel.type))
            }
        }

        return output
    }
}

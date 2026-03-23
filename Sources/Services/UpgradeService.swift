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

    private func upgrade(packages: [String]) async throws -> String {
        let npmPath = NodeRuntime.bundledBinDir.map { "\($0)/npm" } ?? "npm"
        var output = ""
        for pkg in packages {
            let result = try await ShellService.run(npmPath, arguments: ["install", "-g", "\(pkg)@latest"])
            output += result
        }
        return output
    }

    /// Update only components that have newer versions available.
    func upgradeAll(
        daemonInstalledVersion: String,
        daemonWasRunning: Bool,
        channels: [ChannelInfo],
        latestVersions: [String: String],
        extraEnv: (String) -> [String: String],
        stopChannel: (String) async throws -> String,
        syncChannel: (String) async throws -> String,
        startChannel: (String, [String: String]) async throws -> String,
        restartDaemon: () async throws -> String
    ) async throws -> String {
        var output = ""

        // 1. Determine what needs updating
        let daemonNeedsUpdate: Bool = {
            guard let latest = latestVersions["daemon"], !latest.isEmpty, !daemonInstalledVersion.isEmpty
            else { return false }
            return daemonInstalledVersion.compare(latest, options: .numeric) == .orderedAscending
        }()

        let channelsToUpdate = channels.filter { ch in
            guard let latest = latestVersions[ch.type], !latest.isEmpty, !ch.version.isEmpty
            else { return false }
            return ch.version.compare(latest, options: .numeric) == .orderedAscending
        }

        guard daemonNeedsUpdate || !channelsToUpdate.isEmpty else { return "" }

        // 2. Stop channels that need update (before daemon restart)
        for ch in channelsToUpdate where ch.isRunning {
            output += try await stopChannel(ch.type)
        }

        // 3. Update + restart daemon if needed
        if daemonNeedsUpdate {
            output += try await upgrade(packages: npmPackages)
            if daemonWasRunning {
                output += try await restartDaemon()
            }
        }

        // 4. Update + restart channels
        for ch in channelsToUpdate {
            let pkg = ChannelRegistry.entry(for: ch.type, feishuConfig: FeishuConfig())?.packageName
                ?? "@openduo/channel-\(ch.type)"
            output += try await syncChannel(pkg)
            if ch.isRunning {
                output += try await startChannel(ch.type, extraEnv(ch.type))
            }
        }

        return output
    }
}

import Foundation

struct UpgradeService: Sendable {
    private let versionService = VersionService()
    private let runCommand: @Sendable (
        _ executable: String,
        _ arguments: [String],
        _ environment: [String: String]
    ) async throws -> String

    init(
        runCommand: @escaping @Sendable (
            _ executable: String,
            _ arguments: [String],
            _ environment: [String: String]
        ) async throws -> String = { executable, arguments, environment in
            try await ShellService.run(
                executable,
                arguments: arguments,
                environment: environment
            )
        }
    ) {
        self.runCommand = runCommand
    }

    func checkVersions() async throws -> [PackageVersion] {
        let installed = try await versionService.getInstalledVersion("@openduo/duoduo")
        let latest = try await versionService.getNpmLatestVersion("@openduo/duoduo")
        return [PackageVersion(
            name: "@openduo/duoduo",
            installedVersion: installed,
            latestVersion: latest,
            needsUpdate: installed != latest && installed != nil
        )]
    }

    private func upgradeDaemon() async throws -> String {
        do {
            return try await runCommand("duoduo", ["upgrade"], NodeRuntime.environment)
        } catch {
            return try await runCommand(
                "npm",
                ["install", "-g", "@openduo/duoduo"],
                NodeRuntime.environment
            )
        }
    }

    /// Update only components that have newer versions available.
    func upgradeAll(
        daemonInstalledVersion: String,
        daemonWasRunning: Bool,
        channels: [ChannelInfo],
        latestVersions: [String: String],
        stopChannel: (String) async throws -> String,
        syncChannel: (String) async throws -> String,
        startChannel: (String) async throws -> String,
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
            output += try await upgradeDaemon()
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
                output += try await startChannel(ch.type)
            }
        }

        return output
    }
}

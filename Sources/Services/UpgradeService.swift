import Foundation

enum UpgradeTarget: Equatable, Sendable {
    case daemon
    case channel(String)
    case skills
}

struct UpgradeStepError: LocalizedError {
    let step: String
    let reason: String

    var errorDescription: String? {
        L10n.Upgrade.failedDuring(step, reason)
    }
}

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
        channels: [ChannelInfo],
        latestVersions: [String: String],
        stopChannel: (String) async throws -> String,
        syncChannel: (String) async throws -> String,
        startChannel: (String) async throws -> String,
        refreshSkills: () async throws -> String,
        onProgress: @escaping @Sendable (String, UpgradeTarget?) async -> Void
    ) async throws -> String {
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

        var completed: [String] = []

        for ch in channelsToUpdate where ch.isRunning {
            try await runStep(
                L10n.Upgrade.stoppingChannel(ch.displayName),
                target: .channel(ch.type),
                onProgress: onProgress
            ) {
                _ = try await stopChannel(ch.type)
            }
        }

        if daemonNeedsUpdate, let latest = latestVersions["daemon"] {
            try await runStep(
                L10n.Upgrade.updatingDaemon(from: daemonInstalledVersion, to: latest),
                target: .daemon,
                onProgress: onProgress
            ) {
                _ = try await upgradeDaemon()
            }
            completed.append("duoduo \(daemonInstalledVersion) → \(latest)")
        }

        for ch in channelsToUpdate {
            let latest = latestVersions[ch.type] ?? ""
            let pkg = ChannelRegistry.entry(for: ch.type, feishuConfig: FeishuConfig())?.packageName
                ?? "@openduo/channel-\(ch.type)"
            try await runStep(
                L10n.Upgrade.updatingChannel(ch.displayName, from: ch.version, to: latest),
                target: .channel(ch.type),
                onProgress: onProgress
            ) {
                _ = try await syncChannel(pkg)
            }
            completed.append("\(ch.displayName) \(ch.version) → \(latest)")
            if ch.isRunning {
                try await runStep(
                    L10n.Upgrade.startingChannel(ch.displayName),
                    target: .channel(ch.type),
                    onProgress: onProgress
                ) {
                    _ = try await startChannel(ch.type)
                }
            }
        }

        var summary = L10n.Upgrade.updated(completed.joined(separator: ", "))
        if daemonNeedsUpdate {
            await onProgress(L10n.Upgrade.refreshingSkills, .skills)
            do {
                _ = try await refreshSkills()
            } catch {
                summary += " \(L10n.Upgrade.skillsFailed)"
            }
        }

        return summary
    }

    private func runStep(
        _ message: String,
        target: UpgradeTarget?,
        onProgress: @escaping @Sendable (String, UpgradeTarget?) async -> Void,
        operation: () async throws -> Void
    ) async throws {
        await onProgress(message, target)
        do {
            try await operation()
        } catch {
            throw UpgradeStepError(step: message, reason: Self.shortReason(error))
        }
    }

    static func shortReason(_ error: Error) -> String {
        let raw: String
        if case ShellError.executionFailed(let message, _) = error {
            raw = message
        } else {
            raw = error.localizedDescription
        }
        let line = raw
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.count <= 120 { return line }
        return String(line.prefix(117)) + "…"
    }
}

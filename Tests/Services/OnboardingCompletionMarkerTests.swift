import XCTest
@testable import DuoduoManager

final class OnboardingCompletionMarkerTests: XCTestCase {
    func testRequiredConfigurationAcceptsResolvedWorkDirBeforeMarkerExists() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let envURL = tempRoot
            .appendingPathComponent("config", isDirectory: true)
            .appendingPathComponent("duoduo", isDirectory: true)
            .appendingPathComponent(".env", isDirectory: false)
        let configJSONURL = tempRoot
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("duoduo", isDirectory: true)
            .appendingPathComponent("config.json", isDirectory: false)
        ConfigStore.envURLOverride = envURL
        ConfigStore.configJSONURLOverride = configJSONURL
        OnboardingCompletionMarker.homeDirectoryOverride = tempRoot.path
        defer {
            ConfigStore.envURLOverride = nil
            ConfigStore.configJSONURLOverride = nil
            OnboardingCompletionMarker.homeDirectoryOverride = nil
            try? FileManager.default.removeItem(at: tempRoot)
        }

        let config = DaemonConfig(
            workDir: tempRoot.appendingPathComponent("work", isDirectory: true).path,
            daemonHost: "127.0.0.1",
            port: "20233",
            logLevel: "info",
            permissionMode: "default"
        )

        XCTAssertFalse(OnboardingCompletionMarker.hasCompletedConfiguration(daemonConfig: config))
        XCTAssertTrue(OnboardingCompletionMarker.hasRequiredConfiguration(daemonConfig: config))

        config.save()
        XCTAssertTrue(OnboardingCompletionMarker.hasRequiredConfiguration(daemonConfig: config))
        XCTAssertFalse(OnboardingCompletionMarker.hasCompletedConfiguration(daemonConfig: config))

        try OnboardingCompletionMarker.writeConfig(daemonConfig: config)
        XCTAssertTrue(OnboardingCompletionMarker.hasRequiredConfiguration(daemonConfig: config))
        XCTAssertFalse(OnboardingCompletionMarker.hasCompletedConfiguration(daemonConfig: config))

        try OnboardingCompletionMarker.markCompletedIfNeeded(daemonConfig: config)
        XCTAssertTrue(OnboardingCompletionMarker.hasRequiredConfiguration(daemonConfig: config))
        XCTAssertTrue(OnboardingCompletionMarker.hasCompletedConfiguration(daemonConfig: config))
    }

    func testConfigJSONOnlyConfigurationSkipsDaemonRequirement() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let envURL = tempRoot
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("duoduo", isDirectory: true)
            .appendingPathComponent(".env", isDirectory: false)
        ConfigStore.envURLOverride = envURL
        OnboardingCompletionMarker.homeDirectoryOverride = tempRoot.path
        defer {
            ConfigStore.envURLOverride = nil
            ConfigStore.configJSONURLOverride = nil
            OnboardingCompletionMarker.homeDirectoryOverride = nil
            try? FileManager.default.removeItem(at: tempRoot)
        }

        let configURL = envURL.deletingLastPathComponent().appendingPathComponent("config.json", isDirectory: false)
        ConfigStore.configJSONURLOverride = configURL
        try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        {
          "mode": "local",
          "daemonUrl": "http://127.0.0.1:20233",
          "authSource": "claude_code_local",
          "workDir": "\(tempRoot.appendingPathComponent("work", isDirectory: true).path)"
        }
        """.write(to: configURL, atomically: true, encoding: .utf8)

        let config = DaemonConfig.load()

        XCTAssertFalse(ConfigStore.envFileExists)
        XCTAssertEqual(config.workDir, tempRoot.appendingPathComponent("work", isDirectory: true).path)
        XCTAssertEqual(config.port, "20233")
        XCTAssertTrue(OnboardingCompletionMarker.hasRequiredConfiguration(daemonConfig: config))

        try OnboardingCompletionMarker.repairDerivedFilesIfNeeded(daemonConfig: config)
        let envContents = try String(contentsOf: envURL, encoding: .utf8)
        XCTAssertTrue(envContents.contains("ALADUO_WORK_DIR=\(config.workDir)"))
    }

    func testRepairDerivedFilesAlignsConfigJSONToEnv() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let envURL = tempRoot
            .appendingPathComponent("config", isDirectory: true)
            .appendingPathComponent("duoduo", isDirectory: true)
            .appendingPathComponent(".env", isDirectory: false)
        let configJSONURL = tempRoot
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("duoduo", isDirectory: true)
            .appendingPathComponent("config.json", isDirectory: false)
        ConfigStore.envURLOverride = envURL
        ConfigStore.configJSONURLOverride = configJSONURL
        OnboardingCompletionMarker.homeDirectoryOverride = tempRoot.path
        defer {
            ConfigStore.envURLOverride = nil
            ConfigStore.configJSONURLOverride = nil
            OnboardingCompletionMarker.homeDirectoryOverride = nil
            try? FileManager.default.removeItem(at: tempRoot)
        }

        var config = DaemonConfig(
            workDir: tempRoot.appendingPathComponent("work-a", isDirectory: true).path,
            daemonHost: "127.0.0.2",
            port: "20444",
            logLevel: "info",
            permissionMode: "default"
        )
        config.save()
        try OnboardingCompletionMarker.markCompletedIfNeeded(daemonConfig: config)
        XCTAssertTrue(OnboardingCompletionMarker.hasRequiredConfiguration(daemonConfig: config))
        XCTAssertTrue(OnboardingCompletionMarker.hasCompletedConfiguration(daemonConfig: config))

        config.workDir = tempRoot.appendingPathComponent("work-b", isDirectory: true).path
        config.port = "20555"
        config.save()
        XCTAssertTrue(OnboardingCompletionMarker.hasRequiredConfiguration(daemonConfig: config))
        XCTAssertFalse(OnboardingCompletionMarker.hasCompletedConfiguration(daemonConfig: config))

        try OnboardingCompletionMarker.repairDerivedFilesIfNeeded(daemonConfig: config)
        XCTAssertTrue(OnboardingCompletionMarker.hasCompletedConfiguration(daemonConfig: config))

        let document = try JSONDecoder().decode(
            OnboardingConfigDocument.self,
            from: Data(contentsOf: configJSONURL)
        )
        XCTAssertEqual(document.workDir, config.workDir)
        XCTAssertEqual(document.daemonUrl, config.daemonURL)
    }
}

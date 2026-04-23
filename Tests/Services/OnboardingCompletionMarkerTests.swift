import XCTest
@testable import DuoduoManager

final class OnboardingCompletionMarkerTests: XCTestCase {
    func testRequiredConfigurationOnlyRequiresEnvWorkDir() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let envURL = tempRoot
            .appendingPathComponent("config", isDirectory: true)
            .appendingPathComponent("duoduo", isDirectory: true)
            .appendingPathComponent(".env", isDirectory: false)
        ConfigStore.envURLOverride = envURL
        OnboardingCompletionMarker.homeDirectoryOverride = tempRoot.path
        defer {
            ConfigStore.envURLOverride = nil
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
        XCTAssertFalse(OnboardingCompletionMarker.hasRequiredConfiguration(daemonConfig: config))

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

    func testRepairDerivedFilesAlignsConfigJSONToEnv() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let envURL = tempRoot
            .appendingPathComponent("config", isDirectory: true)
            .appendingPathComponent("duoduo", isDirectory: true)
            .appendingPathComponent(".env", isDirectory: false)
        ConfigStore.envURLOverride = envURL
        OnboardingCompletionMarker.homeDirectoryOverride = tempRoot.path
        defer {
            ConfigStore.envURLOverride = nil
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

        let configJSONURL = tempRoot
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("duoduo", isDirectory: true)
            .appendingPathComponent("config.json", isDirectory: false)
        let document = try JSONDecoder().decode(
            OnboardingConfigDocument.self,
            from: Data(contentsOf: configJSONURL)
        )
        XCTAssertEqual(document.workDir, config.workDir)
        XCTAssertEqual(document.daemonUrl, config.daemonURL)
    }
}

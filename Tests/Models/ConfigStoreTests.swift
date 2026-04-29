import XCTest
@testable import DuoduoManager

final class ConfigStoreTests: XCTestCase {
    private var tempDirectory: URL!
    private var envURL: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        envURL = tempDirectory.appendingPathComponent(".config/duoduo/.env")
        ConfigStore.envURLOverride = envURL
    }

    override func tearDownWithError() throws {
        ConfigStore.envURLOverride = nil
        ConfigStore.configJSONURLOverride = nil
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testLoadValuesDecodesQuotedAndPlainEntries() throws {
        try prepareEnv(
            """
            FOO=bar
            BAR="hello world"
            BAZ='quoted'
            """
        )

        let values = ConfigStore.loadValues()

        XCTAssertEqual(values["FOO"], "bar")
        XCTAssertEqual(values["BAR"], "hello world")
        XCTAssertEqual(values["BAZ"], "quoted")
    }

    func testSavePreservesUnmanagedEntriesAndReplacesManagedOnes() throws {
        try prepareEnv(
            """
            KEEP=1

            OLD_KEY=old
            """
        )

        ConfigStore.save(
            entries: [("NEW_KEY", "hello world"), ("BOOL_KEY", "true")],
            managedKeys: ["OLD_KEY", "NEW_KEY", "BOOL_KEY"]
        )

        let contents = try String(contentsOf: envURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("KEEP=1"))
        XCTAssertFalse(contents.contains("OLD_KEY=old"))
        XCTAssertTrue(contents.contains("NEW_KEY=\"hello world\""))
        XCTAssertTrue(contents.contains("BOOL_KEY=true"))
    }

    func testSaveCreatesEnvFileWhenMissing() throws {
        ConfigStore.save(entries: [("ALADUO_PORT", "20233")], managedKeys: ["ALADUO_PORT"])

        let contents = try String(contentsOf: envURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("ALADUO_PORT=20233"))
    }

    func testLoadConfigJSONValuesReadsLegacyDaemonDocument() throws {
        let configURL = tempDirectory.appendingPathComponent(".config/duoduo/config.json")
        try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        {
          "mode": "local",
          "daemonUrl": "http://127.0.0.1:20233",
          "authSource": "claude_code_local",
          "workDir": "/tmp/duoduo-work"
        }
        """.write(to: configURL, atomically: true, encoding: .utf8)

        let values = ConfigStore.loadConfigJSONValues()

        XCTAssertEqual(values["ALADUO_WORK_DIR"], "/tmp/duoduo-work")
        XCTAssertEqual(values["ALADUO_DAEMON_URL"], "http://127.0.0.1:20233")
    }

    func testDaemonConfigFallsBackAcrossEnvConfigJSONAndStatus() throws {
        let configURL = tempDirectory.appendingPathComponent(".config/duoduo/config.json")
        try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        {
          "mode": "local",
          "daemonUrl": "http://127.0.0.1:20444",
          "authSource": "claude_code_local",
          "workDir": "/tmp/config-work"
        }
        """.write(to: configURL, atomically: true, encoding: .utf8)
        var status = DaemonStatus()
        status.daemonConfigValues = ["ALADUO_WORK_DIR": "/tmp/status-work"]

        var config = DaemonConfig.load(status: status)
        XCTAssertEqual(config.workDir, "/tmp/config-work")
        XCTAssertEqual(config.port, "20444")

        try prepareEnv("ALADUO_WORK_DIR=/tmp/env-work")
        config = DaemonConfig.load(status: status)
        XCTAssertEqual(config.workDir, "/tmp/env-work")
        XCTAssertEqual(config.port, "20444")

        try FileManager.default.removeItem(at: configURL)
        try FileManager.default.removeItem(at: envURL)
        config = DaemonConfig.load(status: status)
        XCTAssertEqual(config.workDir, "/tmp/status-work")
    }

    func testDaemonConfigSaveSyncsConfigJSON() throws {
        let configURL = tempDirectory.appendingPathComponent(".config/duoduo/config.json")
        ConfigStore.configJSONURLOverride = configURL

        let config = DaemonConfig(
            workDir: "/tmp/duoduo-work",
            daemonHost: "localhost",
            port: "20444",
            logLevel: "debug",
            permissionMode: "acceptEdits"
        )

        config.save()

        let envContents = try String(contentsOf: envURL, encoding: .utf8)
        XCTAssertTrue(envContents.contains("ALADUO_WORK_DIR=/tmp/duoduo-work"))
        XCTAssertTrue(envContents.contains("ALADUO_DAEMON_HOST=localhost"))
        XCTAssertTrue(envContents.contains("ALADUO_PORT=20444"))

        let document = try JSONDecoder().decode(
            OnboardingConfigDocument.self,
            from: Data(contentsOf: configURL)
        )
        XCTAssertEqual(document.mode, "local")
        XCTAssertEqual(document.authSource, "claude_code_local")
        XCTAssertEqual(document.workDir, "/tmp/duoduo-work")
        XCTAssertEqual(document.daemonUrl, "http://localhost:20444")
    }

    private func prepareEnv(_ content: String) throws {
        try FileManager.default.createDirectory(at: envURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: envURL, atomically: true, encoding: .utf8)
    }
}

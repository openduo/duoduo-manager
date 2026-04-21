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

    private func prepareEnv(_ content: String) throws {
        try FileManager.default.createDirectory(at: envURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: envURL, atomically: true, encoding: .utf8)
    }
}

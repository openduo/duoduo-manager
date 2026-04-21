import XCTest
@testable import DuoduoManager

final class DashboardModelsTests: XCTestCase {
    func testRPCResponseDecodesResultPayload() throws {
        let data = """
        {
          "jsonrpc": "2.0",
          "id": 1,
          "result": {
            "jobs": [
              { "id": "job-1", "frontmatter": { "cron": "*/5 * * * *" }, "state": { "last_result": "success" } }
            ]
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(RPCResponse<JobListResponse>.self, from: data)

        XCTAssertEqual(response.jsonrpc, "2.0")
        XCTAssertEqual(response.id, 1)
        XCTAssertNil(response.error)
        XCTAssertEqual(response.result?.jobs.map(\.id), ["job-1"])
        XCTAssertEqual(response.result?.jobs.first?.state?.last_result, "success")
    }

    func testConfigEntryDecodesStringIntAndBoolValues() throws {
        let stringEntry = try decodeConfigEntry(#"{"value":"debug","source":"env"}"#)
        let intEntry = try decodeConfigEntry(#"{"value":20233,"source":"env"}"#)
        let boolEntry = try decodeConfigEntry(#"{"value":true,"source":"default"}"#)

        XCTAssertEqual(stringEntry.value, "debug")
        XCTAssertEqual(intEntry.value, "20233")
        XCTAssertEqual(boolEntry.value, "true")
    }

    func testBuildDotEnvMapsKnownGroupsAndSkipsUnsetValues() throws {
        let config = SystemConfig(
            network: [
                "port": try decodeConfigEntry(#"{"value":20233,"source":"env"}"#)
            ],
            sessions: nil,
            cadence: nil,
            transfer: nil,
            logging: [
                "log_level": try decodeConfigEntry(#"{"value":"info","source":"env"}"#),
                "sdk_debug": try decodeConfigEntry(#"{"value":true,"source":"unset"}"#)
            ],
            sdk: [
                "base_url": try decodeConfigEntry(#"{"value":"https://example.com","source":"env"}"#),
                "model_sonnet": try decodeConfigEntry(#"{"value":"glm-5","source":"env"}"#)
            ],
            paths: [
                "work_dir": try decodeConfigEntry(#"{"value":"/tmp/work","source":"env"}"#)
            ],
            subconscious: nil
        )

        let dotenv = config.buildDotEnv()

        XCTAssertTrue(dotenv.contains("ALADUO_PORT=20233"))
        XCTAssertTrue(dotenv.contains("ALADUO_LOG_LEVEL=info"))
        XCTAssertTrue(dotenv.contains("ANTHROPIC_BASE_URL=https://example.com"))
        XCTAssertTrue(dotenv.contains("ANTHROPIC_DEFAULT_SONNET=glm-5"))
        XCTAssertTrue(dotenv.contains("ALADUO_WORK_DIR=/tmp/work"))
        XCTAssertFalse(dotenv.contains("sdk_debug"))
    }

    private func decodeConfigEntry(_ json: String) throws -> ConfigEntry {
        try JSONDecoder().decode(ConfigEntry.self, from: Data(json.utf8))
    }
}

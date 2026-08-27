import XCTest
@testable import DuoduoManager

@MainActor
final class ModelProfileStoreTests: XCTestCase {
    func testReloadRefusesOldCLIWithoutCallingService() async {
        let session = FakeSessionService(daemonURL: "http://127.0.0.1:20233")
        session.profileSnapshot.entries = [
            ModelProfileEntry(
                model: "should-not-load",
                max_context_tokens: 1,
                base_url: nil,
                auth: nil,
                source: "global"
            )
        ]
        let store = ModelProfileStore(sessionService: session)

        await store.reload(installedVersion: "0.6.2", daemonRunning: true, channels: [])

        XCTAssertTrue(store.snapshot.entries.isEmpty)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertTrue(store.errorMessage?.contains("0.7.0") == true)
    }

    func testReloadLoadsGlobalProfilesWhenDaemonIsUp() async {
        let session = FakeSessionService(daemonURL: "http://127.0.0.1:20233")
        session.profileSnapshot.entries = [
            ModelProfileEntry(
                model: "deepseek-v4-flash",
                max_context_tokens: 1_000_000,
                base_url: nil,
                auth: nil,
                source: "global"
            )
        ]
        let store = ModelProfileStore(sessionService: session)

        await store.reload(installedVersion: "0.7.1", daemonRunning: true, channels: [
            ChannelInfo(type: "feishu", version: "1.0.0", isRunning: true)
        ])

        XCTAssertEqual(store.snapshot.entries.map(\.model), ["deepseek-v4-flash"])
        XCTAssertNil(store.errorMessage)
        XCTAssertTrue(store.availableScopes.contains(.kind("feishu")))
        XCTAssertTrue(store.availableScopes.contains(.kind("stdio")))
        XCTAssertTrue(store.availableScopes.contains(.kind("job")))
    }

    func testSavePersistsWindowOnlyProfile() async {
        let session = FakeSessionService(daemonURL: "http://127.0.0.1:20233")
        let store = ModelProfileStore(sessionService: session)
        await store.reload(installedVersion: "0.7.1", daemonRunning: true, channels: [])

        let draft = ModelProfileDraft(
            originalModelID: nil,
            modelID: "glm-5.1",
            tokensText: "200000",
            routeToEndpoint: false,
            baseURL: "",
            authField: .anthropicAuthToken,
            token: "",
            existingAuthMasked: nil
        )
        let ok = await store.save(draft)
        XCTAssertTrue(ok)
        XCTAssertEqual(store.snapshot.entries.map(\.model), ["glm-5.1"])
        XCTAssertEqual(store.snapshot.entries.first?.max_context_tokens, 200_000)
        XCTAssertNil(store.snapshot.entries.first?.auth)
    }
}

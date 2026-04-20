import XCTest
@testable import DuoduoManager

@MainActor
final class AppStoreTests: XCTestCase {
    func testRefreshRuntimeUpdatesDaemonStatusAndChannels() async {
        let runtime = RuntimeStore(
            daemonConfig: DaemonConfig(workDir: "", daemonHost: "127.0.0.1", port: "20233", logLevel: "info", permissionMode: "default"),
            feishuConfig: FeishuConfig()
        )
        let channel = ChannelInfo(type: "feishu", version: "0.2.0", isRunning: true, pid: "22")
        let dependencies = TestFactory.dependencies(
            daemonStatus: DaemonStatus(isRunning: true, version: "", pid: "11", output: "healthy: yes", lastUpdated: .now),
            daemonVersion: "0.4.7",
            channelStatuses: ["feishu": channel]
        )
        let store = AppStore(runtime: runtime, dashboard: DashboardStore(), updates: UpdateStore(), command: CommandStore(), dependencies: dependencies)

        await store.refreshRuntime()

        XCTAssertTrue(store.runtime.status.isRunning)
        XCTAssertEqual(store.runtime.status.version, "0.4.7")
        XCTAssertEqual(store.runtime.status.pid, "11")
        XCTAssertEqual(store.runtime.channels.map(\.type), ["feishu"])
    }

    func testCheckForUpdatesPopulatesAppAndRuntimeVersions() async {
        let runtime = RuntimeStore(
            channels: [ChannelInfo(type: "feishu", version: "0.1.0", isRunning: true)],
            daemonConfig: DaemonConfig(),
            feishuConfig: FeishuConfig()
        )
        let dependencies = TestFactory.dependencies(
            latestVersions: ["@openduo/duoduo": "0.4.7", "@openduo/channel-feishu": "0.2.0"],
            latestRelease: AppReleaseInfo(version: "1.6.9", url: URL(string: "https://example.com/release")!)
        )
        let store = AppStore(runtime: runtime, dashboard: DashboardStore(), updates: UpdateStore(), command: CommandStore(), dependencies: dependencies)

        await store.checkForUpdates(force: true)

        XCTAssertEqual(store.updates.appLatestVersion, "1.6.9")
        XCTAssertEqual(store.updates.latestVersions["daemon"], "0.4.7")
        XCTAssertEqual(store.updates.latestVersions["feishu"], "0.2.0")
    }

    func testReconfigureConnectionsReplacesServicesAndClearsDashboardEventState() {
        let runtime = RuntimeStore(
            daemonConfig: DaemonConfig(workDir: "", daemonHost: "127.0.0.1", port: "20233", logLevel: "info", permissionMode: "default"),
            feishuConfig: FeishuConfig()
        )
        let store = AppStore(runtime: runtime, dashboard: DashboardStore(events: [SpineEvent(id: "evt-1", type: "agent.result", session_key: nil, ts: nil, payload: nil)]), updates: UpdateStore(), command: CommandStore(), dependencies: TestFactory.dependencies())
        store.lastEventId = "evt-1"
        store.lastSeenBySession["session-1"] = .now

        store.runtime.daemonConfig = DaemonConfig(workDir: "", daemonHost: "localhost", port: "3000", logLevel: "info", permissionMode: "default")
        store.reconfigureConnectionsIfNeeded()

        XCTAssertEqual(store.daemonService.daemonURL, "http://localhost:3000")
        XCTAssertEqual(store.channelService.daemonURL, "http://localhost:3000")
        XCTAssertEqual(store.rpc.baseURL, "http://localhost:3000")
        XCTAssertTrue(store.dashboard.events.isEmpty)
        XCTAssertNil(store.lastEventId)
        XCTAssertTrue(store.lastSeenBySession.isEmpty)
    }
}

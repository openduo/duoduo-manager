import XCTest
@testable import DuoduoManager

@MainActor
final class AppStoreTests: XCTestCase {
    func testExecuteCommandSuccessRefreshesRuntimeAndDashboard() async {
        let runtime = RuntimeStore(
            daemonConfig: DaemonConfig(workDir: "", daemonHost: "127.0.0.1", port: "20233", logLevel: "info", permissionMode: "default"),
            feishuConfig: FeishuConfig()
        )
        let dependencies = TestFactory.dependencies(
            daemonStatus: DaemonStatus(isRunning: true, version: "", pid: "11", output: "healthy", lastUpdated: .now),
            daemonVersion: "0.4.7",
            systemStatus: SystemStatus(
                sessions: [],
                health: HealthInfo(gateway: "ok", meta_session: "ok"),
                subconscious: nil,
                cadence: nil
            )
        )
        let store = AppStore(
            runtime: runtime,
            dashboard: DashboardStore(),
            updates: UpdateStore(),
            command: CommandStore(),
            dependencies: dependencies
        )
        store.visibleSurfaces = [.popover]

        store.executeCommand { "daemon restarted" }
        await fulfillment(of: [loadingFinishedExpectation(for: store)], timeout: 2)

        XCTAssertEqual(store.command.lastOutput, "daemon restarted")
        XCTAssertNil(store.command.errorMessage)
        XCTAssertTrue(store.runtime.status.isRunning)
        XCTAssertEqual(store.runtime.status.version, "0.4.7")
        XCTAssertEqual(store.dashboard.health?.gateway, "ok")
    }

    func testEnsureDuoduoInstalledIfNeededReportsMissingNode() async {
        let dependencies = TestFactory.dependencies(
            runtimeEnvironment: MutableRuntimeEnvironment(
                isDuoduoInstalled: false,
                hasBundledNode: false,
                hasSystemNode: false
            )
        )
        let store = AppStore(
            runtime: RuntimeStore(daemonConfig: DaemonConfig(), feishuConfig: FeishuConfig()),
            dashboard: DashboardStore(),
            updates: UpdateStore(),
            command: CommandStore(),
            dependencies: dependencies
        )

        await store.ensureDuoduoInstalledIfNeeded()

        XCTAssertEqual(store.command.errorMessage, L10n.Setup.systemNodeMissingTitle)
        XCTAssertEqual(store.command.lastOutput, L10n.Setup.systemNodeMissing)
        XCTAssertFalse(store.runtime.isSettingUp)
    }

    func testEnsureDuoduoInstalledIfNeededMarksSuccessAfterInstall() async {
        let runtimeEnvironment = MutableRuntimeEnvironment(
            isDuoduoInstalled: false,
            hasBundledNode: true,
            hasSystemNode: true,
            installResult: "installed"
        )
        let store = AppStore(
            runtime: RuntimeStore(daemonConfig: DaemonConfig(), feishuConfig: FeishuConfig()),
            dashboard: DashboardStore(),
            updates: UpdateStore(),
            command: CommandStore(),
            dependencies: TestFactory.dependencies(runtimeEnvironment: runtimeEnvironment)
        )

        await store.ensureDuoduoInstalledIfNeeded()

        XCTAssertTrue(runtimeEnvironment.installCallCount == 1)
        XCTAssertEqual(store.command.lastOutput, L10n.Setup.installSuccess)
        XCTAssertNil(store.command.errorMessage)
        XCTAssertFalse(store.runtime.isSettingUp)
    }

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

    private func loadingFinishedExpectation(for store: AppStore) -> XCTestExpectation {
        let expectation = XCTestExpectation(description: "command finished")
        Task {
            while store.command.isLoading {
                try? await Task.sleep(for: .milliseconds(10))
            }
            expectation.fulfill()
        }
        return expectation
    }
}

private final class MutableRuntimeEnvironment: RuntimeEnvironmentProviding, @unchecked Sendable {
    var isDuoduoInstalled: Bool
    let hasBundledNode: Bool
    let hasSystemNode: Bool
    let installResult: String
    private(set) var installCallCount = 0

    init(
        isDuoduoInstalled: Bool,
        hasBundledNode: Bool,
        hasSystemNode: Bool,
        installResult: String = ""
    ) {
        self.isDuoduoInstalled = isDuoduoInstalled
        self.hasBundledNode = hasBundledNode
        self.hasSystemNode = hasSystemNode
        self.installResult = installResult
    }

    func installDuoduo() async throws -> String {
        installCallCount += 1
        isDuoduoInstalled = true
        return installResult
    }
}

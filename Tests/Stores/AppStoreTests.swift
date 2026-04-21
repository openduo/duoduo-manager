import XCTest
@testable import DuoduoManager

@MainActor
final class AppStoreTests: XCTestCase {
    func testFetchDashboardStatusPopulatesUsageJobsAndHealth() async {
        let jobs = JobListResponse(jobs: [
            JobInfo(
                id: "job-1",
                frontmatter: JobFrontmatter(cron: "*/5 * * * *", cwd_rel: "ops", runtime: "shell"),
                state: JobState(last_result: "ok", run_count: 3, last_run_at: "2026-04-21T00:00:00Z")
            )
        ])
        let usage = UsageTotalsResponse(
            totals: UsageTotals(
                total_cost_usd: 4.25,
                total_input_tokens: 100,
                total_output_tokens: 40,
                total_cache_read_tokens: 60,
                total_tool_calls: 7
            )
        )
        let systemStatus = SystemStatus(
            sessions: [
                SessionInfo(
                    session_key: "session:1",
                    status: "active",
                    health: "ok",
                    last_event_at: nil,
                    created_at: nil,
                    last_error: nil,
                    cwd: "/tmp",
                    display_name: "Alpha"
                )
            ],
            health: HealthInfo(gateway: "ok", meta_session: "ok"),
            subconscious: SubconsciousInfo(partitions: [SubconsciousPartition(name: "primary", done: false)]),
            cadence: CadenceInfo(last_tick: "2026-04-21T00:00:00Z", interval_ms: 5000)
        )
        let store = AppStore(
            runtime: RuntimeStore(daemonConfig: DaemonConfig(), feishuConfig: FeishuConfig()),
            dashboard: DashboardStore(),
            updates: UpdateStore(),
            command: CommandStore(),
            dependencies: TestFactory.dependencies(systemStatus: systemStatus, usageTotals: usage, jobs: jobs)
        )

        await store.fetchDashboardStatus()

        XCTAssertEqual(store.dashboard.sessions.map(\.session_key), ["session:1"])
        XCTAssertEqual(store.dashboard.health?.gateway, "ok")
        XCTAssertEqual(store.dashboard.totalCost, 4.25)
        XCTAssertEqual(store.dashboard.totalTokens, 200)
        XCTAssertEqual(store.dashboard.totalTools, 7)
        XCTAssertEqual(store.dashboard.cacheHitRate, 38)
        XCTAssertEqual(store.dashboard.jobs.map(\.id), ["job-1"])
    }

    func testFetchDashboardEventsAppendsEventsAndTracksSessionTimestamps() async {
        let events = SpineTailResponse(events: [
            SpineEvent(id: "evt-1", type: "agent.tool_use", session_key: "session:1", ts: "2026-04-21T00:00:01Z", payload: nil),
            SpineEvent(id: "evt-2", type: "job.started", session_key: "job:sync", ts: "2026-04-21T00:00:02.123Z", payload: nil)
        ])
        let store = AppStore(
            runtime: RuntimeStore(daemonConfig: DaemonConfig(), feishuConfig: FeishuConfig()),
            dashboard: DashboardStore(),
            updates: UpdateStore(),
            command: CommandStore(),
            dependencies: TestFactory.dependencies(events: events)
        )

        await store.fetchDashboardEvents()

        XCTAssertEqual(store.dashboard.events.map(\.id), ["evt-1", "evt-2"])
        XCTAssertEqual(store.lastEventId, "evt-2")
        XCTAssertNotNil(store.lastSeenBySession["session:1"])
        XCTAssertNotNil(store.lastSeenBySession["job:sync"])
    }

    func testFetchConfigStoresSystemConfigResponse() async {
        let config = SystemConfig(
            network: ["port": makeConfigEntry(value: "20233", source: "env")],
            sessions: nil,
            cadence: nil,
            transfer: nil,
            logging: nil,
            sdk: nil,
            paths: nil,
            subconscious: nil
        )
        let store = AppStore(
            runtime: RuntimeStore(daemonConfig: DaemonConfig(), feishuConfig: FeishuConfig()),
            dashboard: DashboardStore(),
            updates: UpdateStore(),
            command: CommandStore(),
            dependencies: TestFactory.dependencies(config: config)
        )

        await store.fetchConfig()

        XCTAssertEqual(store.dashboard.config?.network?["port"]?.value, "20233")
    }

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

    private func makeConfigEntry(value: String, source: String) -> ConfigEntry {
        let data = """
        {"value":"\(value)","source":"\(source)"}
        """.data(using: .utf8)!
        return try! JSONDecoder().decode(ConfigEntry.self, from: data)
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

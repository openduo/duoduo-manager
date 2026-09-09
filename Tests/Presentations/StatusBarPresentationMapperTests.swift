import XCTest
@testable import DuoduoManager

@MainActor
final class StatusBarPresentationMapperTests: XCTestCase {
    func testMakeShowsAppAndRuntimeUpdatesAndUsesErrorMessageInFooter() {
        let runtime = RuntimeStore(
            status: DaemonStatus(isRunning: true, version: "0.4.6", pid: "123", output: "", lastUpdated: .now),
            channels: [ChannelInfo(type: "feishu", version: "0.1.0", isRunning: true, pid: "456")],
            daemonConfig: DaemonConfig(),
            feishuConfig: FeishuConfig(),
            isSettingUp: false
        )
        let dashboard = DashboardStore(
            sessions: [SessionInfo(session_key: "s1", status: "active", health: nil, last_event_at: "2026-01-01T00:00:00Z", created_at: nil, last_error: nil, cwd: nil, display_name: "Session 1")],
            jobs: [JobInfo(id: "job-1", frontmatter: nil, state: JobState(last_result: "success", run_count: 1, last_run_at: "2026-01-01T00:00:00Z"))],
            events: [SpineEvent(id: "evt-1", type: "agent.result", session_key: "s1", ts: "2026-01-01T00:00:00Z", payload: nil)]
        )
        let appLatestVersion = "9.9.9"
        let updates = UpdateStore(latestVersions: ["daemon": "0.4.7", "feishu": "0.2.0"], appLatestVersion: appLatestVersion)
        let command = CommandStore(isLoading: false, lastOutput: "done", errorMessage: "boom")
        let store = AppStore(runtime: runtime, dashboard: dashboard, updates: updates, command: command, dependencies: .live)
        store.lastSeenBySession["job:job-1"] = Date()

        let presentation = StatusBarPresentationMapper(store: store).make(expandedEventIDs: [])

        XCTAssertTrue(presentation.header.showAppUpdate)
        XCTAssertTrue(presentation.header.showRuntimeUpdate)
        XCTAssertEqual(presentation.header.appVersion, appLatestVersion)
        XCTAssertEqual(presentation.daemonCard.latestVersion, "0.4.7")
        XCTAssertEqual(presentation.execution.sessionCaption, "1 active")
        XCTAssertEqual(presentation.execution.jobCaption, "1 running")
        XCTAssertEqual(presentation.footer.statusMessage, "boom")
        XCTAssertTrue(presentation.footer.statusIsError)
    }

    func testMakeFallsBackToWaitingHintWithoutEvents() {
        let store = AppStore(
            runtime: RuntimeStore(),
            dashboard: DashboardStore(),
            updates: UpdateStore(),
            command: CommandStore(),
            dependencies: .live
        )

        let presentation = StatusBarPresentationMapper(store: store).make(expandedEventIDs: [])
        XCTAssertEqual(presentation.stream.hint, "waiting for activity")
    }

    // MARK: - Daemon transport topology semantics (#15)

    func testTopologyShowsConfiguredURLAndHostBeforeUnixSocket() {
        // On a pre-rework CLI, the host value still describes the port the
        // dashboard talks to: loopback → "local runtime", remote → the host.
        var remoteConfig = DaemonConfig()
        remoteConfig.daemonHost = "10.0.0.5"
        remoteConfig.port = "20233"

        let remoteStore = AppStore(
            runtime: RuntimeStore(
                status: DaemonStatus(isRunning: true, version: "0.6.2", pid: "1", output: "", lastUpdated: .now),
                daemonConfig: remoteConfig,
                feishuConfig: FeishuConfig()
            ),
            dashboard: DashboardStore(),
            updates: UpdateStore(),
            command: CommandStore(),
            dependencies: .live
        )
        let remote = StatusBarPresentationMapper(store: remoteStore).make(expandedEventIDs: [])
        XCTAssertEqual(remote.topology.endpoint, "http://10.0.0.5:20233")
        XCTAssertEqual(remote.topology.runtimeHost, "10.0.0.5")
    }

    func testTopologyShowsLoopbackEndpointOnUnixSocketBuild() {
        // After the rework the dashboard always talks to the loopback
        // read-only port, even when the configured host is remote.
        var remoteConfig = DaemonConfig()
        remoteConfig.daemonHost = "10.0.0.5"
        remoteConfig.port = "20233"

        let store = AppStore(
            runtime: RuntimeStore(
                status: DaemonStatus(isRunning: true, version: "0.7.0", pid: "1", output: "", lastUpdated: .now),
                daemonConfig: remoteConfig,
                feishuConfig: FeishuConfig()
            ),
            dashboard: DashboardStore(),
            updates: UpdateStore(),
            command: CommandStore(),
            dependencies: .live
        )
        let presentation = StatusBarPresentationMapper(store: store).make(expandedEventIDs: [])
        XCTAssertEqual(presentation.topology.endpoint, "http://127.0.0.1:20233")
        XCTAssertEqual(presentation.topology.runtimeHost, "local runtime")
    }

    func testSessionDetailIncludesRuntimeWhenPresent() {
        let withRuntime = SessionInfo(
            session_key: "s1",
            status: "active",
            health: "ok",
            last_event_at: nil,
            created_at: nil,
            last_error: nil,
            cwd: nil,
            display_name: "Ada",
            runtime: "codex"
        )
        let withoutRuntime = SessionInfo(
            session_key: "s2",
            status: "idle",
            health: nil,
            last_event_at: nil,
            created_at: nil,
            last_error: nil,
            cwd: nil,
            display_name: "Bob"
        )

        XCTAssertEqual(SharedPresentationFormatting.sessionDetail(withRuntime), "codex · ok")
        XCTAssertEqual(SharedPresentationFormatting.sessionDetail(withoutRuntime), "idle")
    }

    func testSessionDetailIncludesServedAndPendingModel() {
        let served = SessionInfo(
            session_key: "s1",
            status: "active",
            health: "ok",
            last_event_at: nil,
            created_at: nil,
            last_error: nil,
            cwd: nil,
            display_name: "Ada",
            runtime: "codex",
            model: SessionModelInfo(served: "gpt-5.6-sol", pending: nil)
        )
        let switching = SessionInfo(
            session_key: "s2",
            status: "active",
            health: "ok",
            last_event_at: nil,
            created_at: nil,
            last_error: nil,
            cwd: nil,
            display_name: "Ada",
            runtime: "codex",
            model: SessionModelInfo(served: "gpt-5.6-sol", pending: "gpt-5.4")
        )
        let pendingOnly = SessionInfo(
            session_key: "s3",
            status: "idle",
            health: nil,
            last_event_at: nil,
            created_at: nil,
            last_error: nil,
            cwd: nil,
            display_name: "Ada",
            runtime: "codex",
            model: SessionModelInfo(served: nil, pending: "gpt-5.4")
        )

        XCTAssertEqual(SharedPresentationFormatting.sessionDetail(served), "codex · gpt-5.6-sol · ok")
        XCTAssertEqual(SharedPresentationFormatting.sessionDetail(switching), "codex · gpt-5.6-sol → gpt-5.4 · ok")
        XCTAssertEqual(SharedPresentationFormatting.sessionDetail(pendingOnly), "codex · → gpt-5.4")
    }

    func testOperationsMenuDefaultsToActions() {
        let store = AppStore(
            runtime: RuntimeStore(),
            dashboard: DashboardStore(),
            updates: UpdateStore(),
            command: CommandStore(),
            dependencies: TestFactory.dependencies()
        )

        let presentation = StatusBarPresentationMapper(store: store).make(expandedEventIDs: [])
        XCTAssertEqual(presentation.operations.title, L10n.Status.actions)
        XCTAssertEqual(presentation.operations.installSkillsTitle, L10n.Skills.install)
        XCTAssertEqual(presentation.operations.autostartTitle, L10n.Autostart.enable)
        XCTAssertFalse(presentation.operations.autostartEnabled)
        XCTAssertFalse(presentation.operations.isDisabled)
    }

    func testOperationsMenuShowsDisableWhenAutostartEnabled() {
        let store = AppStore(
            runtime: RuntimeStore(isAutostartEnabled: true),
            dashboard: DashboardStore(),
            updates: UpdateStore(),
            command: CommandStore(),
            dependencies: TestFactory.dependencies()
        )

        let presentation = StatusBarPresentationMapper(store: store).make(expandedEventIDs: [])
        XCTAssertEqual(presentation.operations.autostartTitle, L10n.Autostart.disable)
        XCTAssertTrue(presentation.operations.autostartEnabled)
    }

    func testOperationsMenuKeepsActionsTitleWhileBusy() {
        let store = AppStore(
            runtime: RuntimeStore(),
            dashboard: DashboardStore(),
            updates: UpdateStore(),
            command: CommandStore(
                isLoading: true,
                activeOperation: .autostart,
                lastOutput: L10n.Autostart.enabling
            ),
            dependencies: TestFactory.dependencies()
        )

        let presentation = StatusBarPresentationMapper(store: store).make(expandedEventIDs: [])
        XCTAssertEqual(presentation.operations.title, L10n.Status.actions)
        XCTAssertEqual(presentation.operations.installSkillsTitle, L10n.Skills.install)
        XCTAssertTrue(presentation.operations.isDisabled)
        XCTAssertEqual(presentation.footer.statusMessage, L10n.Autostart.enabling)
        XCTAssertFalse(presentation.footer.statusIsError)
    }
}

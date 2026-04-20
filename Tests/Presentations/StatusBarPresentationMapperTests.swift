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
        let updates = UpdateStore(latestVersions: ["daemon": "0.4.7", "feishu": "0.2.0"], appLatestVersion: "1.6.9")
        let command = CommandStore(isLoading: false, lastOutput: "done", errorMessage: "boom")
        let store = AppStore(runtime: runtime, dashboard: dashboard, updates: updates, command: command, dependencies: .live)
        store.lastSeenBySession["job:job-1"] = Date()

        let presentation = StatusBarPresentationMapper(store: store).make(expandedEventIDs: [])

        XCTAssertTrue(presentation.header.showAppUpdate)
        XCTAssertTrue(presentation.header.showRuntimeUpdate)
        XCTAssertEqual(presentation.header.appVersion, "1.6.9")
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
}

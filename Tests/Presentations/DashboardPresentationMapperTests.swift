import XCTest
@testable import DuoduoManager

@MainActor
final class DashboardPresentationMapperTests: XCTestCase {
    func testMakeBuildsSidebarGroupsInReverseRecentSessionOrder() {
        let events = [
            SpineEvent(id: "1", type: "agent.result", session_key: "session:a", ts: "2026-01-01T00:00:00Z", payload: nil),
            SpineEvent(id: "2", type: "agent.tool_use", session_key: "session:b", ts: "2026-01-01T00:00:01Z", payload: nil),
            SpineEvent(id: "3", type: "agent.tool_result", session_key: "session:b", ts: "2026-01-01T00:00:02Z", payload: nil),
            SpineEvent(id: "4", type: "system.note", session_key: nil, ts: "2026-01-01T00:00:03Z", payload: nil)
        ]
        let sessions = [
            SessionInfo(session_key: "session:a", status: "active", health: nil, last_event_at: nil, created_at: nil, last_error: nil, cwd: nil, display_name: "Alpha"),
            SessionInfo(session_key: "session:b", status: "idle", health: nil, last_event_at: nil, created_at: nil, last_error: nil, cwd: nil, display_name: "Beta")
        ]
        let dashboard = DashboardStore(
            sessions: sessions,
            health: HealthInfo(gateway: "ok", meta_session: "ok"),
            subconscious: SubconsciousInfo(partitions: [SubconsciousPartition(name: "partition-long-name", done: true)]),
            jobs: [],
            events: events,
            totalCost: 12.34,
            totalTokens: 12345,
            totalTools: 8,
            cacheHitRate: 66
        )
        let store = AppStore(runtime: RuntimeStore(), dashboard: dashboard, updates: UpdateStore(), command: CommandStore(), dependencies: .live)

        let presentation = DashboardPresentationMapper.make(store: store)

        XCTAssertEqual(presentation.sidebarGroups.map(\.key), ["session:b", "session:a"])
        XCTAssertEqual(presentation.sidebarGroups.first?.count, 2)
        XCTAssertEqual(presentation.sidebarGroups.first?.eventTypes.map(\.type), ["agent.tool_use", "agent.tool_result"])
        XCTAssertEqual(presentation.systemEvents.map(\.id), ["4"])
        XCTAssertEqual(presentation.bottomStats.costText, DashboardTheme.formatCost(12.34))
        XCTAssertEqual(presentation.bottomStats.tokenText, "tok:\(DashboardTheme.formatTokens(12345))")
        XCTAssertEqual(presentation.bottomStats.subconsciousItems.first?.name, SharedPresentationFormatting.shortPartitionName("partition-long-name"))
    }

    func testBottomStatsUsesErrorColorWhenHealthIsDown() {
        let dashboard = DashboardStore(
            health: HealthInfo(gateway: "down", meta_session: "ok")
        )
        let store = AppStore(runtime: RuntimeStore(), dashboard: dashboard, updates: UpdateStore(), command: CommandStore(), dependencies: .live)

        let presentation = DashboardPresentationMapper.make(store: store)

        XCTAssertEqual(presentation.bottomStats.healthText, SharedPresentationFormatting.dashboardHealthText(dashboard.health))
        XCTAssertEqual(presentation.bottomStats.healthColor.description, DashboardTheme.red.description)
    }
}

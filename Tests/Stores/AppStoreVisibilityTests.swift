import XCTest
@testable import DuoduoManager

@MainActor
final class AppStoreVisibilityTests: XCTestCase {
    func testSetPopoverVisibleStartsPollingTasks() async {
        let runtimeEnvironment = FakeRuntimeEnvironment(isDuoduoInstalled: true, hasBundledNode: true, hasSystemNode: true, installResult: "")
        let store = AppStore(
            runtime: RuntimeStore(),
            dashboard: DashboardStore(),
            updates: UpdateStore(),
            command: CommandStore(),
            dependencies: TestFactory.dependencies(runtimeEnvironment: runtimeEnvironment)
        )

        store.setPopoverVisible(true)
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(store.visibleSurfaces.contains(.popover))
        XCTAssertNotNil(store.runtimeRefreshTask)
        XCTAssertNotNil(store.dashboardEventsTask)
        XCTAssertNotNil(store.dashboardStatusTask)
        XCTAssertTrue(store.hasPreparedInteractiveSession)
    }

    func testHidingAllSurfacesStopsPollingTasks() async {
        let runtimeEnvironment = FakeRuntimeEnvironment(isDuoduoInstalled: true, hasBundledNode: true, hasSystemNode: true, installResult: "")
        let store = AppStore(
            runtime: RuntimeStore(),
            dashboard: DashboardStore(),
            updates: UpdateStore(),
            command: CommandStore(),
            dependencies: TestFactory.dependencies(runtimeEnvironment: runtimeEnvironment)
        )

        store.setPopoverVisible(true)
        try? await Task.sleep(for: .milliseconds(50))
        store.setPopoverVisible(false)

        XCTAssertTrue(store.visibleSurfaces.isEmpty)
        XCTAssertNil(store.runtimeRefreshTask)
        XCTAssertNil(store.dashboardEventsTask)
        XCTAssertNil(store.dashboardStatusTask)
    }

    func testShutdownCancelsAndClearsTasks() async {
        let store = AppStore(
            runtime: RuntimeStore(),
            dashboard: DashboardStore(),
            updates: UpdateStore(),
            command: CommandStore(),
            dependencies: TestFactory.dependencies(runtimeEnvironment: FakeRuntimeEnvironment())
        )

        store.setPopoverVisible(true)
        try? await Task.sleep(for: .milliseconds(50))
        store.shutdown()

        XCTAssertTrue(store.visibleSurfaces.isEmpty)
        XCTAssertNil(store.prepareInteractiveSessionTask)
        XCTAssertNil(store.runtimeRefreshTask)
        XCTAssertNil(store.dashboardEventsTask)
        XCTAssertNil(store.dashboardStatusTask)
    }
}

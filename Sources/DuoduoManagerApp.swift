import SwiftUI

@main
struct DuoduoManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Dummy scene: satisfies SwiftUI's Scene requirement, auto-closes on appear.
        WindowGroup("") {
            EmptyView()
                .onAppear {
                    for window in NSApp.windows where window.title.isEmpty {
                        window.close()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1, height: 1)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: AppStore?
    private var statusController: AppStatusController?
    private var windowController: AppWindowController?

    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            if let resourceURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
               let icon = NSImage(contentsOf: resourceURL) {
                NSApp.applicationIconImage = icon
            }

            NSApp.setActivationPolicy(.accessory)
            statusController = AppStatusController()
            windowController = AppWindowController()
            initViewModel()
        }
    }

    nonisolated func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            store?.shutdown()
            statusController?.shutdown()
            windowController?.shutdown()
        }
    }

    nonisolated func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Setup

    private func initViewModel() {
        store = AppStore()
        store?.updateStatusBarIcon = { [weak self] in
            self?.updateStatusBarIcon()
        }
        statusController?.onPopoverVisibilityChanged = { [weak self] isVisible in
            self?.store?.setPopoverVisible(isVisible)
        }
        windowController?.onDashboardVisibilityChanged = { [weak self] isVisible in
            self?.store?.setDashboardVisible(isVisible)
        }
        updatePopoverContent()
        updateStatusBarIcon()
    }

    private func updatePopoverContent() {
        guard let store else { return }
        statusController?.setPopoverContent(StatusBarView(
            store: store,
            openDashboard: { [weak self] in self?.openDashboard() },
            openReader: { [weak self] in self?.openReader() }
        ))
        updateStatusBarIcon()
    }

    private func updateStatusBarIcon() {
        guard let store else { return }
        statusController?.updateStatusIcon(
            hasAppUpdate: store.hasAppUpdate,
            isRuntimeRunning: store.runtime.status.isRunning
        )
    }

    // MARK: - Dashboard

    private func openDashboard() {
        statusController?.dismissPopover()
        guard let store else { return }
        windowController?.showDashboard(store: store)
    }

    // MARK: - CC Reader

    private func openReader() {
        statusController?.dismissPopover()
        windowController?.showReader()
    }
}

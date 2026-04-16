import SwiftUI
import CCReaderKit

@main
struct DuoduoManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Dummy scene: satisfies SwiftUI's Scene requirement, auto-closes on appear.
        WindowGroup("") {
            LaunchBridgeView(appDelegate: appDelegate)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1, height: 1)

        Window("CC Reader", id: "cc-reader") {
            CCReaderSceneView()
        }
        .defaultSize(width: 1200, height: 800)
    }
}

private struct LaunchBridgeView: View {
    @Environment(\.openWindow) private var openWindow

    let appDelegate: AppDelegate

    var body: some View {
        EmptyView()
            .onAppear {
                appDelegate.registerOpenReaderWindowAction {
                    openWindow(id: "cc-reader")
                }

                DispatchQueue.main.async {
                    for window in NSApp.windows where window.title.isEmpty {
                        window.close()
                    }
                }
            }
    }
}

private struct CCReaderSceneView: View {
    var body: some View {
        CCReaderKit.makeView()
            .onDisappear {
                AppDelegate.restoreAccessoryPolicyIfNeeded()
            }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: AppStore?
    private var statusController: AppStatusController?
    private var windowController: AppWindowController?
    private var openReaderWindowAction: (() -> Void)?

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
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            self.openReaderWindowAction?()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func registerOpenReaderWindowAction(_ action: @escaping () -> Void) {
        openReaderWindowAction = action
    }

    static func restoreAccessoryPolicyIfNeeded() {
        let hasOtherVisibleWindow = NSApp.windows.contains {
            $0.isVisible && $0.styleMask.contains(.titled) && !$0.title.isEmpty
        }
        if !hasOtherVisibleWindow {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

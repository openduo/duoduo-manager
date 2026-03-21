import SwiftUI

@main
struct DuoduoManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var viewModel: DaemonViewModel?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var dashboardWindow: NSPanel?

    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            if let resourceURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
               let icon = NSImage(contentsOf: resourceURL) {
                NSApp.applicationIconImage = icon
            }

            NSApp.setActivationPolicy(.accessory)

            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

            if let button = statusItem?.button {
                if let sfImage = NSImage(systemSymbolName: "dog.fill", accessibilityDescription: "Duoduo") {
                    let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
                    button.image = sfImage.withSymbolConfiguration(config)
                }
                button.action = #selector(togglePopover)
                button.target = self
            }

            let popover = NSPopover()
            popover.behavior = .transient
            popover.animates = true
            popover.delegate = self
            self.popover = popover

            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                Task { @MainActor in
                    self?.closePopover()
                }
            }

            initViewModel()
        }
    }

    nonisolated func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            viewModel?.endPeriodicRefresh()
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }

    // MARK: - NSPopoverDelegate

    func popoverWillClose(_ notification: Notification) {
        viewModel?.endPeriodicRefresh()
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowShouldClose(_ sender: NSWindow) -> Bool {
        Task { @MainActor in
            sender.orderOut(nil)
            NSApp.setActivationPolicy(.accessory)
        }
        return false
    }

    // MARK: - Setup

    private func initViewModel() {
        viewModel = DaemonViewModel()
        viewModel?.updateStatusBarIcon = { [weak self] in
            self?.updateStatusBarIcon()
        }
        updatePopoverContent()
        Task {
            await viewModel?.refreshStatus()
            self.updateStatusBarIcon()
        }
    }

    private func updatePopoverContent() {
        guard let viewModel else { return }
        popover?.contentViewController = NSHostingController(rootView: StatusBarView(
            viewModel: viewModel,
            openDashboard: { [weak self] in self?.openDashboard() }
        ))
        updateStatusBarIcon()
    }

    private func updateStatusBarIcon() {
        guard let viewModel else { return }
        statusItem?.button?.toolTip = "Duoduo Manager - \(viewModel.status.isRunning ? L10n.Status.running : L10n.Status.stopped)"
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if let popover, popover.isShown {
            popover.performClose(nil)
        } else if let popover {
            viewModel?.beginPeriodicRefresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func closePopover() {
        if let popover, popover.isShown {
            popover.performClose(nil)
        }
    }

    // MARK: - Dashboard

    private func openDashboard() {
        closePopover()

        if dashboardWindow == nil {
            let dashboardView = DashboardView()
            dashboardWindow = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            dashboardWindow?.title = "Duoduo ATC"
            dashboardWindow?.titlebarAppearsTransparent = true
            dashboardWindow?.contentViewController = NSHostingController(rootView: dashboardView)
            dashboardWindow?.setContentSize(NSSize(width: 1100, height: 700))
            dashboardWindow?.delegate = self
            dashboardWindow?.minSize = NSSize(width: 680, height: 500)
            dashboardWindow?.center()
            dashboardWindow?.isReleasedWhenClosed = false
        }

        dashboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

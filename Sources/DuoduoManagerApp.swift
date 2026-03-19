import SwiftUI

@main
struct DuoduoManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("Duoduo ATC", id: "atc") {
            DashboardView()
        }
        .defaultSize(width: 860, height: 600)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var viewModel: DaemonViewModel?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            // Load custom icon for app
            if let resourceURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
               let icon = NSImage(contentsOf: resourceURL) {
                NSApp.applicationIconImage = icon
            }

            // Hide the auto-created dashboard window and go menu-bar-only
            NSApp.setActivationPolicy(.accessory)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                for window in NSApp.windows where window.title == "Duoduo ATC" {
                    window.delegate = self
                    window.orderOut(nil)
                }
            }

            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

            if let button = statusItem?.button {
                // Use SF Symbols for auto light/dark mode support
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

            // Add global click event monitor
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

        if let window = NSApp.windows.first(where: { $0.title == "Duoduo ATC" }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

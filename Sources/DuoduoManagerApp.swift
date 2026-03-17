import SwiftUI

@main
struct DuoduoManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No window scenes needed — this is a menu bar app
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private var viewModel: DaemonViewModel?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            NSApp.setActivationPolicy(.accessory)

            // Load custom icon for app
            if let resourceURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
               let icon = NSImage(contentsOf: resourceURL) {
                NSApp.applicationIconImage = icon
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

    // MARK: - Setup

    private func initViewModel() {
        // Migrate legacy workDir from AppStorage to DaemonConfig
        if let legacyWorkDir = UserDefaults.standard.string(forKey: "workDir"),
           !legacyWorkDir.isEmpty {
            var config = DaemonConfig.load()
            if config.workDir.isEmpty {
                config.workDir = legacyWorkDir
                config.save()
            }
            UserDefaults.standard.removeObject(forKey: "workDir")
        }

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
        popover?.contentViewController = NSHostingController(rootView: StatusBarView(viewModel: viewModel))
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
}

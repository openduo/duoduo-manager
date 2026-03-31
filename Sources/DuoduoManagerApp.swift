import SwiftUI
import CCReaderKit

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
class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var viewModel: DaemonViewModel?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var dashboardWindow: NSWindow?
    private var readerWindow: NSWindow?
    private var windowCloseObserver: Any?

    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            if let resourceURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
               let icon = NSImage(contentsOf: resourceURL) {
                NSApp.applicationIconImage = icon
            }

            NSApp.setActivationPolicy(.accessory)

            // Switch back to .accessory when all titled windows are closed
            windowCloseObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: nil,
                queue: .main
            ) { _ in
                DispatchQueue.main.async {
                    let hasVisibleWindow = NSApp.windows.contains {
                        $0.isVisible && $0.styleMask.contains(.titled) && !$0.title.isEmpty
                    }
                    if !hasVisibleWindow {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
            }

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
            if let observer = windowCloseObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    nonisolated func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - NSPopoverDelegate

    func popoverWillClose(_ notification: Notification) {
        viewModel?.endPeriodicRefresh()
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowShouldClose(_ sender: NSWindow) -> Bool {
        Task { @MainActor in
            sender.orderOut(nil)
            let hasOtherVisibleWindow = NSApp.windows.contains {
                $0.isVisible && $0 != sender && $0.styleMask.contains(.titled) && !$0.title.isEmpty
            }
            if !hasOtherVisibleWindow {
                NSApp.setActivationPolicy(.accessory)
            }
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
            await viewModel?.ensureDuoduoInstalled()
            await viewModel?.refreshStatus()
            self.updateStatusBarIcon()
        }
    }

    private func updatePopoverContent() {
        guard let viewModel else { return }
        popover?.contentViewController = NSHostingController(rootView: StatusBarView(
            viewModel: viewModel,
            openDashboard: { [weak self] in self?.openDashboard() },
            openReader: { [weak self] in self?.openReader() }
        ))
        updateStatusBarIcon()
    }

    private func updateStatusBarIcon() {
        guard let viewModel else { return }
        let icon: String
        if viewModel.hasAppUpdate {
            icon = "dot.radiowaves.left.and.badge.plus"
        } else {
            icon = "dog.fill"
        }
        if let button = statusItem?.button,
           let sfImage = NSImage(systemSymbolName: icon, accessibilityDescription: "Duoduo") {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            button.image = sfImage.withSymbolConfiguration(config)
        }
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

        let dashboardURL = viewModel?.daemonConfig.daemonURL ?? "http://127.0.0.1:20233"

        if dashboardWindow == nil {
            let dashboardView = DashboardView(daemonURL: dashboardURL)
            dashboardWindow = NSWindow(
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
            dashboardWindow?.hidesOnDeactivate = false
            dashboardWindow?.center()
            dashboardWindow?.isReleasedWhenClosed = false
            dashboardWindow?.collectionBehavior = [.managed, .participatesInCycle, .fullScreenAllowsTiling]
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.dashboardWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - CC Reader

    private func openReader() {
        closePopover()

        if readerWindow == nil {
            let readerView = CCReaderKit.makeView()
            readerWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            readerWindow?.title = "CC Reader"
            let toolbar = NSToolbar(identifier: "CCReaderToolbar")
            toolbar.displayMode = .iconOnly
            readerWindow?.toolbar = toolbar
            readerWindow?.toolbarStyle = .unified
            readerWindow?.contentViewController = NSHostingController(rootView: readerView)
            readerWindow?.setContentSize(NSSize(width: 1200, height: 800))
            readerWindow?.delegate = self
            readerWindow?.minSize = NSSize(width: 680, height: 500)
            readerWindow?.center()
            readerWindow?.isReleasedWhenClosed = false
            readerWindow?.collectionBehavior = [.managed, .participatesInCycle, .fullScreenAllowsTiling]
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.readerWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

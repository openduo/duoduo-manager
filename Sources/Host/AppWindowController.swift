import AppKit
import SwiftUI
import CCReaderKit

@MainActor
final class AppWindowController: NSObject, NSWindowDelegate {
    private var dashboardWindow: NSWindow?
    private var readerWindow: NSWindow?

    var onDashboardVisibilityChanged: ((Bool) -> Void)?

    func showDashboard(store: AppStore) {
        if dashboardWindow == nil {
            let dashboardView = DashboardView(store: store)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Duoduo ATC"
            window.titlebarAppearsTransparent = true
            window.contentViewController = NSHostingController(rootView: dashboardView)
            window.setContentSize(NSSize(width: 1100, height: 700))
            window.delegate = self
            window.minSize = NSSize(width: 680, height: 500)
            window.hidesOnDeactivate = false
            window.center()
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.managed, .participatesInCycle, .fullScreenAllowsTiling]
            dashboardWindow = window
        }

        onDashboardVisibilityChanged?(true)
        showWindow(dashboardWindow)
    }

    func showReader() {
        if readerWindow == nil {
            let readerView = CCReaderKit.makeView()
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "CC Reader"
            let toolbar = NSToolbar(identifier: "CCReaderToolbar")
            toolbar.displayMode = .iconOnly
            window.toolbar = toolbar
            window.toolbarStyle = .unified
            window.contentViewController = NSHostingController(rootView: readerView)
            window.setContentSize(NSSize(width: 1200, height: 800))
            window.delegate = self
            window.minSize = NSSize(width: 680, height: 500)
            window.center()
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.managed, .participatesInCycle, .fullScreenAllowsTiling]
            readerWindow = window
        }

        showWindow(readerWindow)
    }

    func shutdown() {
        dashboardWindow?.delegate = nil
        readerWindow?.delegate = nil
    }

    nonisolated func windowShouldClose(_ sender: NSWindow) -> Bool {
        Task { @MainActor in
            if sender == self.dashboardWindow {
                self.onDashboardVisibilityChanged?(false)
            }
            sender.orderOut(nil)
            self.restoreAccessoryPolicyIfNeeded(excluding: sender)
        }
        return false
    }

    private func showWindow(_ window: NSWindow?) {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func restoreAccessoryPolicyIfNeeded(excluding sender: NSWindow) {
        let hasOtherVisibleWindow = NSApp.windows.contains {
            $0.isVisible && $0 != sender && $0.styleMask.contains(.titled) && !$0.title.isEmpty
        }
        if !hasOtherVisibleWindow {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

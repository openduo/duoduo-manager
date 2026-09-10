import AppKit
import SwiftUI

@MainActor
final class AppStatusController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var eventMonitor: Any?

    var onPopoverVisibilityChanged: ((Bool) -> Void)?
    var onPopOut: (() -> Void)?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        super.init()

        popover.behavior = .transient
        popover.animates = true
        popover.appearance = OpenDuo.nsAppearance
        popover.delegate = self

        if let button = statusItem.button {
            if let sfImage = NSImage(systemSymbolName: "dog.fill", accessibilityDescription: "Duoduo") {
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
                button.image = sfImage.withSymbolConfiguration(config)
            }
            button.action = #selector(statusItemClicked)
            button.target = self
            // Default NSButton behavior sends on left mouse-up; widening the
            // mask to right mouse-up is what routes right-clicks here too.
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.closePopover()
            }
        }
    }

    func shutdown() {
        closePopover()
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        eventMonitor = nil
    }

    func dismissPopover() {
        closePopover()
    }

    func setPopoverContent<Content: View>(_ content: Content) {
        popover.contentViewController = NSHostingController(rootView: content)
    }

    func updateStatusIcon(hasAppUpdate: Bool, isRuntimeRunning: Bool) {
        let icon = hasAppUpdate ? "dot.radiowaves.left.and.badge.plus" : "dog.fill"
        if let button = statusItem.button,
           let sfImage = NSImage(systemSymbolName: icon, accessibilityDescription: "Duoduo") {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            button.image = sfImage.withSymbolConfiguration(config)
            button.toolTip = "Duoduo Manager - \(isRuntimeRunning ? L10n.Status.running : L10n.Status.stopped)"
        }
    }

    // MARK: - Status item clicks

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }

        switch event.type {
        case .rightMouseUp:
            showStatusMenu()
        default:
            togglePopover()
        }
    }

    /// The right-click menu: pop the popover content out into a window, or
    /// quit. Popped up synchronously under the item — deliberately NOT via
    /// button.menu + performClick: on this OS performClick still dispatches
    /// the button action, which would re-enter statusItemClicked and recurse
    /// until the stack guard kills the process.
    private func showStatusMenu() {
        guard let button = statusItem.button else { return }
        closePopover()

        let menu = NSMenu()

        let popOutItem = NSMenuItem(
            title: L10n.Status.popOut,
            action: #selector(popOutClicked),
            keyEquivalent: ""
        )
        popOutItem.target = self
        menu.addItem(popOutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: L10n.Status.quit,
            action: #selector(quitClicked),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        // The status bar window is flipped: y = height is the point just
        // below the button, where the menu drops down from.
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }

    @objc private func popOutClicked() {
        onPopOut?()
    }

    @objc private func quitClicked() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            onPopoverVisibilityChanged?(true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func closePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }

    func popoverWillClose(_ notification: Notification) {
        onPopoverVisibilityChanged?(false)
    }
}

import AppKit
import SwiftUI

@MainActor
final class AppStatusController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var eventMonitor: Any?

    var onPopoverVisibilityChanged: ((Bool) -> Void)?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        super.init()

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        if let button = statusItem.button {
            if let sfImage = NSImage(systemSymbolName: "dog.fill", accessibilityDescription: "Duoduo") {
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
                button.image = sfImage.withSymbolConfiguration(config)
            }
            button.action = #selector(togglePopover)
            button.target = self
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

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            onPopoverVisibilityChanged?(true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
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

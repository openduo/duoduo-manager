import AppKit
import SwiftUI

/// The detached status window: the popover's `StatusBarView` in a free-standing
/// titled window, opened from the status item's right-click menu. Owns the
/// same visibility contract as the popover — while it is on screen, the
/// popover-driven polling keeps running.
@MainActor
final class StatusWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let contentSize = NSSize(width: 520, height: 680)

    var onVisibilityChanged: ((Bool) -> Void)?

    func show(content: AnyView) {
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(origin: .zero, size: contentSize),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            w.title = "Duoduo Manager"
            w.titlebarAppearsTransparent = true
            w.titlebarSeparatorStyle = .none
            w.titleVisibility = .hidden
            w.appearance = OpenDuo.nsAppearance
            w.backgroundColor = OpenDuo.nsPage
            w.contentViewController = NSHostingController(rootView: content)
            w.setContentSize(contentSize)
            w.minSize = contentSize
            w.delegate = self
            w.isReleasedWhenClosed = false
            w.isMovableByWindowBackground = true
            w.hidesOnDeactivate = false
            w.center()
            window = w
        }

        onVisibilityChanged?(true)
        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func shutdown() {
        window?.delegate = nil
    }

    nonisolated func windowShouldClose(_ sender: NSWindow) -> Bool {
        Task { @MainActor in
            self.onVisibilityChanged?(false)
            sender.orderOut(nil)
            self.restoreAccessoryPolicyIfNeeded(excluding: sender)
        }
        return false
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

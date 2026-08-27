import AppKit
import SwiftUI

@MainActor
final class ModelProfilesWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let store: AppStore

    var onClose: (() -> Void)?

    init(appStore: AppStore) {
        store = appStore
    }

    func show() {
        if window == nil {
            let view = ModelProfilesView(store: store)
            let hosting = NSHostingController(rootView: view)
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            w.title = L10n.ModelProfiles.windowTitle
            w.contentViewController = hosting
            w.setContentSize(NSSize(width: 760, height: 560))
            w.minSize = NSSize(width: 720, height: 480)
            w.delegate = self
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }

        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    nonisolated func windowShouldClose(_ sender: NSWindow) -> Bool {
        Task { @MainActor in
            sender.orderOut(nil)
            restoreAccessoryPolicyIfNeeded(excluding: sender)
            self.onClose?()
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

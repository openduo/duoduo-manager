import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let store: OnboardingStore

    var onClose: (() -> Void)?

    init(appStore: AppStore? = nil, preferredRequirement: OnboardingRequirement? = nil) {
        store = OnboardingStore(appStore: appStore, preferredRequirement: preferredRequirement)
    }

    func show() {
        if window == nil {
            let view = OnboardingView(
                store: store,
                onClose: { [weak self] in
                    self?.window?.close()
                    self?.onClose?()
                }
            )
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            w.title = ""
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.contentViewController = NSHostingController(rootView: view)
            w.setContentSize(NSSize(width: 520, height: 440))
            w.delegate = self
            w.isReleasedWhenClosed = false
            w.isMovableByWindowBackground = true
            w.backgroundColor = .clear
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

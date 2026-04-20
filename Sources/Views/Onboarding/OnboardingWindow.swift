import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let store: OnboardingStore
    private let preferredWidth: CGFloat = 620
    private let minHeight: CGFloat = 440
    private let maxHeight: CGFloat = 760

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
                },
                onPreferredHeightChange: { [weak self] height in
                    self?.updateWindowHeight(height)
                }
            )
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: preferredWidth, height: minHeight),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            w.title = ""
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.contentViewController = NSHostingController(rootView: view)
            w.setContentSize(NSSize(width: preferredWidth, height: minHeight))
            w.minSize = NSSize(width: preferredWidth, height: minHeight)
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

    private func updateWindowHeight(_ height: CGFloat) {
        guard let window else { return }
        let targetHeight = max(minHeight, min(maxHeight, ceil(height)))
        let current = window.contentLayoutRect.size
        guard abs(current.height - targetHeight) > 1 || abs(current.width - preferredWidth) > 1 else { return }
        window.setContentSize(NSSize(width: preferredWidth, height: targetHeight))
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

import SwiftUI
import CCReaderKit
import Sparkle

@main
struct DuoduoManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Dummy scene: satisfies SwiftUI's Scene requirement, auto-closes on appear.
        WindowGroup("") {
            LaunchBridgeView(appDelegate: appDelegate)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1, height: 1)

        Window("CC Reader", id: "cc-reader") {
            CCReaderSceneView()
        }
        .defaultSize(width: 1200, height: 800)
    }
}

private struct LaunchBridgeView: View {
    @Environment(\.openWindow) private var openWindow

    let appDelegate: AppDelegate

    var body: some View {
        EmptyView()
            .onAppear {
                appDelegate.registerOpenReaderWindowAction {
                    openWindow(id: "cc-reader")
                }

                DispatchQueue.main.async {
                    for window in NSApp.windows where window.title.isEmpty {
                        window.close()
                    }
                }
            }
    }
}

private struct CCReaderSceneView: View {
    var body: some View {
        CCReaderKit.makeView()
            .onDisappear {
                AppDelegate.restoreAccessoryPolicyIfNeeded()
            }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, SPUUpdaterDelegate {
    private var store: AppStore?
    private var statusController: AppStatusController?
    private var windowController: AppWindowController?
    private var onboardingController: OnboardingWindowController?
    private var openReaderWindowAction: (() -> Void)?
    lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: self,
        userDriverDelegate: nil
    )

    /// The build variant channel from Info.plist (e.g. "arm64-with-nodejs", "universal-lite")
    private var buildVariantChannel: String? {
        Bundle.main.object(forInfoDictionaryKey: "DuoduoBuildVariant") as? String
    }

    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            if let resourceURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
               let icon = NSImage(contentsOf: resourceURL) {
                NSApp.applicationIconImage = icon
            }

            NSApp.setActivationPolicy(.accessory)
            statusController = AppStatusController()
            windowController = AppWindowController()
            initViewModel()
        }
    }

    nonisolated func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            store?.shutdown()
            statusController?.shutdown()
            windowController?.shutdown()
        }
    }

    nonisolated func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Setup

    private func initViewModel() {
        store = AppStore()
        store?.checkForSparkleUpdate = { [weak self] in
            self?.updaterController.checkForUpdates(nil)
        }
        store?.checkForSparkleUpdateSilently = { [weak self] in
            self?.updaterController.updater.checkForUpdateInformation()
        }
        store?.updateStatusBarIcon = { [weak self] in
            self?.updateStatusBarIcon()
        }
        statusController?.onPopoverVisibilityChanged = { [weak self] isVisible in
            self?.store?.setPopoverVisible(isVisible)
        }
        windowController?.onDashboardVisibilityChanged = { [weak self] isVisible in
            self?.store?.setDashboardVisible(isVisible)
        }
        updatePopoverContent()
        updateStatusBarIcon()
        checkAndShowOnboarding()
    }

    private func checkAndShowOnboarding() {
        Task {
            await store?.refreshRuntime()
            let snapshot = await OnboardingService.detect(appStore: store)
            let critical = snapshot.unmetRequirements.filter { $0 != .daemon }
            let daemonConfig = store?.runtime.daemonConfig ?? .load()
            let hasRequiredConfiguration = OnboardingCompletionMarker.hasRequiredConfiguration(daemonConfig: daemonConfig)

            if critical.isEmpty, hasRequiredConfiguration {
                try? OnboardingCompletionMarker.repairDerivedFilesIfNeeded(daemonConfig: daemonConfig)
                return
            }

            if !critical.isEmpty || !hasRequiredConfiguration {
                let preferredRequirement: OnboardingRequirement? = critical.isEmpty ? .daemon : nil
                await MainActor.run { showOnboarding(at: preferredRequirement) }
            }
        }
    }

    private func showOnboarding(at preferredRequirement: OnboardingRequirement? = nil) {
        guard onboardingController == nil else { return }
        let controller = OnboardingWindowController(appStore: store, preferredRequirement: preferredRequirement)
        controller.onClose = { [weak self] in
            self?.onboardingController = nil
        }
        onboardingController = controller
        controller.show()
    }

    private func updatePopoverContent() {
        guard let store else { return }
        statusController?.setPopoverContent(StatusBarView(
            store: store,
            openDashboard: { [weak self] in self?.openDashboard() },
            openReader: { [weak self] in self?.openReader() },
            openOnboard: { [weak self] in self?.openOnboarding(at: .claudeAccess) }
        ))
        updateStatusBarIcon()
    }

    private func updateStatusBarIcon() {
        guard let store else { return }
        statusController?.updateStatusIcon(
            hasAppUpdate: store.hasAppUpdate,
            isRuntimeRunning: store.runtime.status.isRunning
        )
    }

    // MARK: - Dashboard

    private func openDashboard() {
        statusController?.dismissPopover()
        guard let store else { return }
        windowController?.showDashboard(store: store)
    }

    private func openOnboarding(at preferredRequirement: OnboardingRequirement?) {
        statusController?.dismissPopover()
        showOnboarding(at: preferredRequirement)
    }

    // MARK: - CC Reader

    private func openReader() {
        statusController?.dismissPopover()
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            self.openReaderWindowAction?()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func registerOpenReaderWindowAction(_ action: @escaping () -> Void) {
        openReaderWindowAction = action
    }

    static func restoreAccessoryPolicyIfNeeded() {
        let hasOtherVisibleWindow = NSApp.windows.contains {
            $0.isVisible && $0.styleMask.contains(.titled) && !$0.title.isEmpty
        }
        if !hasOtherVisibleWindow {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: - SPUUpdaterDelegate

    nonisolated func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        if let channel = Bundle.main.object(forInfoDictionaryKey: "DuoduoBuildVariant") as? String {
            return [channel]
        }
        return []
    }

    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        Task { @MainActor in
            guard store?.updates.appLatestVersion != item.displayVersionString else { return }
            store?.updates.appLatestVersion = item.displayVersionString
        }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        Task { @MainActor in
            guard store?.updates.appLatestVersion != nil else { return }
            store?.updates.appLatestVersion = nil
        }
    }
}

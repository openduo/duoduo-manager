import SwiftUI

extension StatusBarView {
    var statusBarMapper: StatusBarPresentationMapper {
        StatusBarPresentationMapper(store: store)
    }

    var statusBarPresentation: StatusBarPresentationBundle {
        statusBarMapper.make(expandedEventIDs: expandedEventIDs)
    }
}

extension StatusBarView {
    var daemonConfigBinding: Binding<DaemonConfig> {
        Binding(
            get: { store.runtime.daemonConfig },
            set: { store.updateDaemonConfig($0) }
        )
    }

    var feishuConfigBinding: Binding<FeishuConfig> {
        Binding(
            get: { store.runtime.feishuConfig },
            set: { store.updateFeishuConfig($0) }
        )
    }

}

extension StatusBarView {
    func toggleEvent(_ eventID: String) {
        if expandedEventIDs.contains(eventID) {
            expandedEventIDs.remove(eventID)
        } else {
            expandedEventIDs.insert(eventID)
        }
    }

    func openCCReader() {
        openReader?()
    }

    func showConfigPanel<V: View>(title: String, @ViewBuilder content: @escaping () -> V) {
        let hostingController = NSHostingController(rootView: content())
        let panel = NSPanel(contentViewController: hostingController)
        panel.title = title
        panel.styleMask = [.titled, .closable]
        panel.isReleasedWhenClosed = false
        hostingController.view.layoutSubtreeIfNeeded()
        let size = hostingController.view.fittingSize
        panel.setContentSize(NSSize(width: max(size.width, 380), height: size.height))
        panel.minSize = NSSize(width: 380, height: 200)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

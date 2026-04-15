import SwiftUI

enum InlineConfigTarget {
    case daemon
    case feishu
}

struct InlineConfigNotice {
    let message: String
    let tint: Color
    let actionTitle: String?
    let action: (() -> Void)?
}

extension StatusBarView {
    var statusBarMapper: StatusBarPresentationMapper {
        StatusBarPresentationMapper(store: store)
    }

    var statusBarPresentation: StatusBarPresentationBundle {
        statusBarMapper.make(expandedEventIDs: expandedEventIDs)
    }
}

extension StatusBarView {
    var daemonRuntimeHint: String? {
        (daemonNotice?.actionTitle != nil && store.runtime.status.isRunning) ? "restart required" : nil
    }

    var daemonRuntimeHintTint: Color? {
        daemonRuntimeHint == nil ? nil : ConsolePalette.warning
    }

    func feishuRuntimeHint(channelIsRunning: Bool) -> String? {
        if feishuNotice?.actionTitle != nil && channelIsRunning {
            return "restart required"
        }
        return nil
    }

    func feishuRuntimeHintTint(channelIsRunning: Bool) -> Color? {
        feishuRuntimeHint(channelIsRunning: channelIsRunning) == nil ? nil : ConsolePalette.warning
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

    func toggleConfig(_ target: InlineConfigTarget) {
        if expandedConfigTarget == target {
            cancelConfig(target)
            return
        }

        switch target {
        case .daemon:
            daemonDraft = store.runtime.daemonConfig
            daemonNotice = nil
        case .feishu:
            feishuDraft = store.runtime.feishuConfig
            feishuNotice = nil
        }

        expandedConfigTarget = target
    }

    func cancelConfig(_ target: InlineConfigTarget) {
        switch target {
        case .daemon:
            daemonDraft = store.runtime.daemonConfig
            daemonNotice = nil
        case .feishu:
            feishuDraft = store.runtime.feishuConfig
            feishuNotice = nil
        }
        if expandedConfigTarget == target {
            expandedConfigTarget = nil
        }
    }

    func saveDaemonDraft() {
        let previous = store.runtime.daemonConfig
        daemonDraft.save()
        store.updateDaemonConfig(daemonDraft)

        let needsRestart = previous != daemonDraft && store.runtime.status.isRunning
        daemonNotice = InlineConfigNotice(
            message: needsRestart ? "saved · restart required" : "saved",
            tint: needsRestart ? ConsolePalette.warning : ConsolePalette.signal,
            actionTitle: needsRestart ? "restart" : nil,
            action: needsRestart ? {
                store.restartDaemon()
                daemonNotice = nil
            } : nil
        )
    }

    func saveFeishuDraft() {
        let previous = store.runtime.feishuConfig
        feishuDraft.save()
        store.updateFeishuConfig(feishuDraft)

        let runningChannel = store.runtime.channels.first(where: { $0.type == "feishu" && $0.isRunning }) != nil
        let needsRestart = previous != feishuDraft && runningChannel
        feishuNotice = InlineConfigNotice(
            message: needsRestart ? "saved · restart required" : "saved",
            tint: needsRestart ? ConsolePalette.warning : ConsolePalette.signal,
            actionTitle: needsRestart ? "restart" : nil,
            action: needsRestart ? {
                store.restartChannel("feishu")
                feishuNotice = nil
            } : nil
        )
    }
}

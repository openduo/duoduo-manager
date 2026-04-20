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

    func openTerminal() {
        let env = NodeRuntime.environment
        var exports: [String] = []
        if let path = env["PATH"] {
            exports.append("PATH='\(path.escapingSingleQuotes)'")
        }
        if let prefix = env["NPM_CONFIG_PREFIX"] {
            exports.append("NPM_CONFIG_PREFIX='\(prefix.escapingSingleQuotes)'")
        }
        if let nodePath = env["NODE_PATH"] {
            exports.append("NODE_PATH='\(nodePath.escapingSingleQuotes)'")
        }
        let script = "export \(exports.joined(separator: " ")); clear"

        let appleScript = """
        tell application "Terminal"
            activate
            do script "\(script.escapingBackslashAndQuotes)"
        end tell
        """
        if let nsScript = NSAppleScript(source: appleScript) {
            var error: NSDictionary?
            nsScript.executeAndReturnError(&error)
        }
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
        daemonDraft.save()
        store.updateDaemonConfig(daemonDraft)
        daemonNotice = nil
    }

    func saveFeishuDraft() {
        feishuDraft.save()
        store.updateFeishuConfig(feishuDraft)
        feishuNotice = nil
    }
}

private extension String {
    var escapingSingleQuotes: String {
        replacingOccurrences(of: "'", with: "'\\''")
    }

    var escapingBackslashAndQuotes: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

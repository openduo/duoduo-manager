import SwiftUI

private let terminalLogFile = "\(NSHomeDirectory())/Library/Application Support/\(Bundle.main.bundleIdentifier ?? "ai.openduo.manager")/debug.log"
private let terminalLogQueue = DispatchQueue(label: "com.duoduo.terminal.log")
private let terminalDateFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

private func writeTerminalLog(_ message: String) {
    terminalLogQueue.async {
        let line = "[\(terminalDateFormatter.string(from: Date()))] [Terminal] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        let logURL = URL(fileURLWithPath: terminalLogFile)
        let logDirURL = logURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: logDirURL, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: terminalLogFile) {
            FileManager.default.createFile(atPath: terminalLogFile, contents: nil)
        }
        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        }
    }
}

enum PreferredTerminalApp: String, CaseIterable {
    case appleTerminal
    case iterm2
    case ghostty

    private var descriptor: (title: String, bundleID: String, openName: String) {
        switch self {
        case .appleTerminal: return ("Terminal", "com.apple.Terminal", "Terminal")
        case .iterm2:        return ("iTerm2",  "com.googlecode.iterm2", "iTerm")
        case .ghostty:       return ("Ghostty", "com.mitchellh.ghostty", "Ghostty")
        }
    }

    var title: String { descriptor.title }
    var bundleIdentifier: String { descriptor.bundleID }
    var openAppName: String { descriptor.openName }

    var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }
}

enum TerminalLaunchError: LocalizedError {
    case appNotInstalled(String)
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .appNotInstalled(let app):
            return "\(app) is not installed"
        case .launchFailed(let message):
            return message
        }
    }
}

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
        var terminalApp = PreferredTerminalApp(rawValue: preferredTerminalAppRaw) ?? .appleTerminal
        if !terminalApp.isInstalled {
            let fallback = PreferredTerminalApp.allCases.first(where: { $0.isInstalled }) ?? .appleTerminal
            writeTerminalLog("preferred \(terminalApp.title) not installed, fallback to \(fallback.title)")
            terminalApp = fallback
            preferredTerminalAppRaw = fallback.rawValue
        }
        do {
            try launchTerminal(app: terminalApp)
            store.command.errorMessage = nil
            writeTerminalLog("<<< openTerminal success")
        } catch {
            writeTerminalLog("<<< openTerminal ERROR: \(error.localizedDescription)")
            store.command.errorMessage = error.localizedDescription
            store.scheduleCommandFeedbackAutoClear()
        }
    }

    private func launchTerminal(app: PreferredTerminalApp) throws {
        let workDir = resolvedTerminalWorkingDirectory()
        let exports = bundledRuntimeExportCommands()
        writeTerminalLog("launchTerminal: app=\(app.title) workDir=\(workDir) hasBundledNode=\(NodeRuntime.hasBundledNode)")

        let targetPath: String
        if exports.isEmpty {
            targetPath = workDir
        } else {
            targetPath = makeTerminalInitScript(workDir: workDir, exports: exports)
        }

        try runProcess(executable: "/usr/bin/open", arguments: ["-a", app.openAppName, targetPath])
    }

    private func makeTerminalInitScript(workDir: String, exports: [String]) -> String {
        let path = "\(NSTemporaryDirectory())duoduo-terminal-init-\(UUID().uuidString).command"
        let lines = ["#!/bin/zsh"] + exports + [
            "cd '\(workDir.escapingSingleQuotes)'",
            "clear",
            "exec \"$SHELL\"",
        ]
        let script = lines.joined(separator: "\n")
        try? script.write(toFile: path, atomically: true, encoding: .utf8)
        _ = try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        writeTerminalLog("makeTerminalInitScript: \(path)\n\(script)")
        return path
    }

    private func resolvedTerminalWorkingDirectory() -> String {
        let configured = store.runtime.daemonConfig.workDir.trimmingCharacters(in: .whitespacesAndNewlines)
        if isUsableDirectory(configured) { return configured }

        if isUsableDirectory(DaemonConfig.defaultWorkDir) {
            return DaemonConfig.defaultWorkDir
        }
        return NSHomeDirectory()
    }

    private func bundledRuntimeExportCommands() -> [String] {
        guard NodeRuntime.hasBundledNode else { return [] }

        let env = NodeRuntime.environment
        let exportedKeys = ["PATH", "NPM_CONFIG_PREFIX", "NODE_PATH", DuoduoCompat.nodeBinEnvVar]
        return exportedKeys.compactMap { key -> String? in
            guard let value = env[key], !value.isEmpty else { return nil }
            return "export \(key)='\(value.escapingSingleQuotes)'"
        }
    }

    private func runProcess(executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        do {
            try process.run()
        } catch {
            throw TerminalLaunchError.launchFailed(error.localizedDescription)
        }
    }

    private func isUsableDirectory(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
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
}

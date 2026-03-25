import Foundation

enum ShellError: LocalizedError {
    case executionFailed(String, exitCode: Int32)

    var errorDescription: String? {
        switch self {
        case .executionFailed(let message, _):
            return L10n.Error.executionFailed(message)
        }
    }
}

struct ShellService: Sendable {
    private static let logFile = "\(NSHomeDirectory())/Library/Application Support/\(Bundle.main.bundleIdentifier ?? "ai.openduo.manager")/debug.log"
    private static let logQueue = DispatchQueue(label: "com.duoduo.shell.log")

    private static func writeLog(_ message: String) {
        logQueue.async {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium)
            let line = "[\(timestamp)] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }
            if FileManager.default.fileExists(atPath: logFile) {
                if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: logFile)) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                }
            } else {
                FileManager.default.createFile(atPath: logFile, contents: data)
            }
        }
    }

    /// Run a subprocess directly — no shell intermediate.
    static func run(
        _ executable: String,
        arguments: [String],
        environment overrides: [String: String] = [:],
        workingDirectory: String? = nil
    ) async throws -> String {
        let cmdDesc = "\(executable) \(arguments.joined(separator: " "))"
        writeLog(">>> \(cmdDesc)")
        if let dir = workingDirectory {
            writeLog("    cwd: \(dir)")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            var env = NodeRuntime.environment
            for (key, value) in overrides {
                env[key] = value
            }
            process.environment = env

            if let dir = workingDirectory {
                process.currentDirectoryURL = URL(fileURLWithPath: dir)
            }

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                var output = String(data: outputData, encoding: .utf8) ?? ""

                if process.terminationStatus != 0 {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                    writeLog("<<< exit \(process.terminationStatus)\n\(output)\n[stderr]\n\(errorOutput)")
                    if !errorOutput.isEmpty {
                        output += "\n[stderr]\n" + errorOutput
                    }
                    continuation.resume(throwing: ShellError.executionFailed(output, exitCode: process.terminationStatus))
                    return
                }

                writeLog("<<< exit 0\n\(output)")
                continuation.resume(returning: output)
            } catch {
                writeLog("<<< FAILED: \(error)")
                continuation.resume(throwing: ShellError.executionFailed(error.localizedDescription, exitCode: -1))
            }
        }
    }
}

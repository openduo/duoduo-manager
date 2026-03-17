import Foundation

enum ShellError: LocalizedError {
    case executionFailed(String)
    case processNotFound(String)

    var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return L10n.Error.executionFailed(message)
        case .processNotFound(let cmd):
            return L10n.Error.commandNotFound(cmd)
        }
    }
}

struct ShellService: Sendable {
    static func run(_ executable: String, arguments: [String], environment: [String: String] = [:]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            var env = ProcessInfo.processInfo.environment
            for (key, value) in environment {
                env[key] = value
            }
            process.environment = env

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
                    if !errorOutput.isEmpty {
                        output += "\n[stderr]\n" + errorOutput
                    }
                }

                continuation.resume(returning: output)
            } catch {
                continuation.resume(throwing: ShellError.executionFailed(error.localizedDescription))
            }
        }
    }

    static func runShell(_ script: String, environment: [String: String] = [:]) async throws -> String {
        // Explicitly source shell config files to load user environment (nvm/node, etc.)
        // GUI apps don't inherit shell PATH, so we need to load it manually
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let sourceCmd: String
        if shell.contains("zsh") {
            sourceCmd = "source ~/.zshrc 2>/dev/null || true; source ~/.zprofile 2>/dev/null || true"
        } else {
            sourceCmd = "source ~/.bashrc 2>/dev/null || true; source ~/.bash_profile 2>/dev/null || true"
        }
        let fullScript = "\(sourceCmd); \(script)"
        return try await run(shell, arguments: ["-c", fullScript], environment: environment)
    }
}

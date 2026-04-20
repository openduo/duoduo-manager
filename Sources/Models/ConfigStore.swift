import Foundation

enum ConfigStore {
    private static let envURL: URL = {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("duoduo", isDirectory: true)
            .appendingPathComponent(".env", isDirectory: false)
    }()

    private enum Line {
        case blank(String)
        case comment(String)
        case entry(key: String, rawValue: String)
        case other(String)

        var text: String {
            switch self {
            case .blank(let raw), .comment(let raw), .other(let raw):
                raw
            case .entry(let key, let rawValue):
                "\(key)=\(rawValue)"
            }
        }
    }

    static func loadValues() -> [String: String] {
        parseDocument().values
    }

    static func save(entries: [(key: String, value: String)], managedKeys: Set<String>) {
        do {
            try ensureEnvFile()
            let document = parseDocument()
            let filtered = document.lines.filter { line in
                if case .entry(let key, _) = line {
                    return !managedKeys.contains(key)
                }
                return true
            }

            var output = trimTrailingBlankLines(filtered)
            let renderedEntries = entries.map { Line.entry(key: $0.key, rawValue: encode($0.value)) }
            if !renderedEntries.isEmpty {
                if !output.isEmpty, !endsWithBlankLine(output) {
                    output.append(.blank(""))
                }
                output.append(contentsOf: renderedEntries)
            }

            let body = output.map(\.text).joined(separator: "\n")
            try body.write(to: envURL, atomically: true, encoding: .utf8)
        } catch {
            NSLog("ConfigStore save failed: \(error.localizedDescription)")
        }
    }

    private static func parseDocument() -> (lines: [Line], values: [String: String]) {
        guard let content = try? String(contentsOf: envURL, encoding: .utf8) else {
            return ([], [:])
        }

        let rawLines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var lines: [Line] = []
        var values: [String: String] = [:]

        for rawLine in rawLines {
            let line = parse(rawLine)
            lines.append(line)
            if case .entry(let key, let rawValue) = line {
                values[key] = decode(rawValue)
            }
        }

        return (lines, values)
    }

    private static func parse(_ rawLine: String) -> Line {
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return .blank(rawLine)
        }
        if trimmed.hasPrefix("#") {
            return .comment(rawLine)
        }

        let pattern = #"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: rawLine, range: NSRange(rawLine.startIndex..., in: rawLine)),
            let keyRange = Range(match.range(at: 1), in: rawLine),
            let valueRange = Range(match.range(at: 2), in: rawLine)
        else {
            return .other(rawLine)
        }

        let key = String(rawLine[keyRange])
        let rawValue = String(rawLine[valueRange])
        return .entry(key: key, rawValue: rawValue)
    }

    private static func decode(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return trimmed }

        let first = trimmed.first
        let last = trimmed.last
        guard (first == "\"" && last == "\"") || (first == "'" && last == "'") else {
            return trimmed
        }

        let inner = String(trimmed.dropFirst().dropLast())
        if first == "\"" {
            return inner
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")
        }
        return inner.replacingOccurrences(of: "\\'", with: "'")
    }

    private static func encode(_ value: String) -> String {
        if value.isEmpty {
            return "\"\""
        }

        let needsQuoting = value.contains { character in
            character.isWhitespace || character == "#" || character == "\"" || character == "'" || character == "\\"
        }
        guard needsQuoting else { return value }

        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    private static func ensureEnvFile() throws {
        let directory = envURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        if !FileManager.default.fileExists(atPath: envURL.path) {
            try "".write(to: envURL, atomically: true, encoding: .utf8)
        }
    }

    private static func trimTrailingBlankLines(_ lines: [Line]) -> [Line] {
        var result = lines
        while let last = result.last, case .blank = last {
            result.removeLast()
        }
        return result
    }

    private static func endsWithBlankLine(_ lines: [Line]) -> Bool {
        guard let last = lines.last else { return false }
        if case .blank = last {
            return true
        }
        return false
    }
}

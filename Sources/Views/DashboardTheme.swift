import SwiftUI

enum DashboardTheme {
    // Backgrounds — Catppuccin Mocha inspired, layered with warm undertones
    static let background = Color(red: 24/255, green: 24/255, blue: 37/255)
    static let sidebarBackground = Color(red: 17/255, green: 17/255, blue: 27/255)
    static let cardBackground = Color(red: 30/255, green: 30/255, blue: 46/255)

    // Borders / dividers — warm-tinted, very subtle
    static let border = Color(red: 69/255, green: 71/255, blue: 90/255).opacity(0.5)
    static let sidebarDivider = Color(red: 69/255, green: 71/255, blue: 90/255).opacity(0.3)

    // Text — proper hierarchy, all readable on dark bg
    static let text = Color(red: 205/255, green: 214/255, blue: 244/255)
    static let textSecondary = Color(red: 166/255, green: 173/255, blue: 200/255)
    static let textTertiary = Color(red: 88/255, green: 91/255, blue: 112/255)
    static let sidebarHeaderText = Color(red: 108/255, green: 112/255, blue: 134/255)
    static let sidebarItemText = Color(red: 147/255, green: 153/255, blue: 178/255)

    // Accents — Catppuccin Mocha pastels, soft and distinctive
    static let accent = Color(red: 148/255, green: 226/255, blue: 213/255)       // Teal
    static let emerald = Color(red: 166/255, green: 227/255, blue: 161/255)       // Green
    static let amber = Color(red: 249/255, green: 226/255, blue: 175/255)         // Yellow
    static let red = Color(red: 243/255, green: 139/255, blue: 168/255)           // Red
    static let blue = Color(red: 137/255, green: 180/255, blue: 250/255)          // Blue
    static let fuchsia = Color(red: 203/255, green: 166/255, blue: 247/255)       // Mauve

    // Sidebar selected
    static let sidebarActive = Color(red: 49/255, green: 50/255, blue: 68/255)

    // MARK: - Formatting

    static func formatCost(_ n: Double) -> String {
        if n >= 1000 { return "$\((n / 1000).formatted(.number.precision(.fractionLength(1))))k" }
        return "$\(n.formatted(.number.precision(.fractionLength(2))))"
    }

    static func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return "\(Double(n / 1_000_000).formatted(.number.precision(.fractionLength(1))))M" }
        if n >= 1000 { return "\(Double(n / 1000).formatted(.number.precision(.fractionLength(0))))k" }
        return "\(n)"
    }

    static func formatTools(_ n: Int) -> String {
        if n >= 1000 { return "\(Double(n / 1000).formatted(.number.precision(.fractionLength(1))))k" }
        return "\(n)"
    }

    // MARK: - Event Type Color

    static func color(forEventType type: String) -> Color {
        switch type {
        case "agent.tool_use":    return amber
        case "agent.tool_result": return emerald
        case "agent.result":      return accent
        case "route.deliver":     return fuchsia
        case "channel.message":   return blue
        case "agent.error":       return red
        case "job.spawn", "job.complete", "job.fail": return fuchsia
        default:                   return textTertiary
        }
    }

    // MARK: - Date Helpers

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SS"
        return df
    }()

    static func formatTime(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func parseISO8601(_ s: String) -> Date {
        (try? Date(s, strategy: .iso8601)) ?? Date()
    }

    static func timeAgo(_ s: String) -> String {
        let seconds = Int(Date.now.timeIntervalSince(parseISO8601(s)))
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        return "\(seconds / 86400)d"
    }

    // MARK: - JSON

    static func prettyJSON<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8)
        else { return "{}" }
        return str
    }
}

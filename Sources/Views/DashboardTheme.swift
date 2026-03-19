import SwiftUI

enum DashboardTheme {
    // Backgrounds
    static let background = Color(red: 17/255, green: 17/255, blue: 17/255)
    static let sidebarBackground = Color(red: 13/255, green: 13/255, blue: 13/255)
    static let cardBackground = Color(red: 22/255, green: 22/255, blue: 22/255)

    // Borders / dividers
    static let border = Color(red: 34/255, green: 34/255, blue: 34/255)
    static let sidebarDivider = Color(red: 26/255, green: 26/255, blue: 26/255)

    // Text
    static let text = Color(red: 232/255, green: 232/255, blue: 232/255)
    static let textSecondary = Color(red: 136/255, green: 136/255, blue: 136/255)
    static let textTertiary = Color(red: 68/255, green: 68/255, blue: 68/255)
    static let sidebarHeaderText = Color(red: 51/255, green: 51/255, blue: 51/255)
    static let sidebarItemText = Color(red: 119/255, green: 119/255, blue: 119/255)

    // Neon highlights
    static let accent = Color(red: 0, green: 212/255, blue: 170/255)        // #00d4aa cyan-green
    static let emerald = Color(red: 0, green: 255/255, blue: 159/255)       // #00ff9f
    static let amber = Color(red: 255/255, green: 140/255, blue: 0)         // #ff8c00
    static let red = Color(red: 255/255, green: 68/255, blue: 68/255)       // #ff4444
    static let blue = Color(red: 77/255, green: 159/255, blue: 255/255)     // #4d9fff
    static let fuchsia = Color(red: 204/255, green: 68/255, blue: 255/255)  // #cc44ff

    // Sidebar selected
    static let sidebarActive = Color(red: 0, green: 212/255, blue: 170/255).opacity(0.12)

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

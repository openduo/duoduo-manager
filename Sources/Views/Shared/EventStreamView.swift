import SwiftUI

// MARK: - Event Row

struct EventRowView: View {
    let event: SpineEvent
    let isExpanded: Bool
    var onToggle: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Log line: chevron | time | [type] | summary — clickable to toggle expand
            Button(action: onToggle) {
                HStack(alignment: .center, spacing: 8) {
                    // Expand indicator
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(isExpanded ? DashboardTheme.accent.opacity(0.6) : DashboardTheme.textTertiary.opacity(0.5))
                        .frame(width: 16)

                    // Time
                    Text(timeString)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(DashboardTheme.textTertiary)

                    // [type]
                    typeTag

                    // Summary content
                    eventSummary
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.top, 5)
                .padding(.bottom, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded: raw JSON (not inside Button, so text selection works)
            if isExpanded {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(DashboardTheme.accent)
                        .frame(width: 2)
                    Text(rawJSON)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DashboardTheme.textSecondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(DashboardTheme.sidebarBackground)
                }
                .padding(.leading, 16)
                .padding(.top, 2)
                .padding(.bottom, 6)
            }

            Rectangle().fill(DashboardTheme.border).frame(height: 1)
        }
    }

    // MARK: - Type Tag

    @ViewBuilder
    private var typeTag: some View {
        let (label, color) = typeInfo
        HStack(spacing: 0) {
            Text("[").foregroundStyle(DashboardTheme.accent)
            Text(label.padding(toLength: 11, withPad: " ", startingAt: 0)).foregroundStyle(color)
            Text("]").foregroundStyle(DashboardTheme.accent)
        }
        .font(.system(size: 12, design: .monospaced))
    }

    private var typeInfo: (label: String, color: Color) {
        let last = String(event.type.split(separator: ".").last ?? Substring(event.type))
        return (last, DashboardTheme.color(forEventType: event.type))
    }

    // MARK: - Summary (single line)

    @ViewBuilder
    private var eventSummary: some View {
        switch event.type {
        case "agent.tool_use":
            toolUseSummary
        case "agent.tool_result":
            toolResultSummary
        case "agent.result":
            agentResultSummary
        case "route.deliver":
            routeDeliverSummary
        case "channel.message":
            channelMessageSummary
        case "agent.error":
            agentErrorSummary
        default:
            fallbackSummary
        }
    }

    private var toolUseSummary: some View {
        HStack(spacing: 6) {
            Text(">").foregroundStyle(DashboardTheme.amber)
            Text(event.payload?.tool_name ?? "?")
                .foregroundStyle(DashboardTheme.amber).fontWeight(.medium)
            Text(toolDesc).foregroundStyle(DashboardTheme.textSecondary)
        }
        .font(.system(size: 12, design: .monospaced))
    }

    private var toolResultSummary: some View {
        let isError = event.payload?.is_error == true
        let tool = event.payload?.tool_name ?? ""
        let summary = event.payload?.summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let oneLineSummary = summary.replacing("\n", with: " ")
        return HStack(spacing: 6) {
            Text(isError ? "x" : "+")
                .foregroundStyle(isError ? DashboardTheme.red : DashboardTheme.emerald)
                .fontWeight(.semibold)
            if !tool.isEmpty { Text(tool).foregroundStyle(DashboardTheme.textSecondary) }
            if !oneLineSummary.isEmpty {
                Text(oneLineSummary).foregroundStyle(DashboardTheme.textTertiary)
            }
        }
        .font(.system(size: 12, design: .monospaced))
    }

    private var agentResultSummary: some View {
        let part = event.payload?.partition.map { "[\($0)] " } ?? ""
        let text = (event.payload?.text ?? "").replacing("\n", with: " ")
        return HStack(spacing: 4) {
            Text("->").foregroundStyle(DashboardTheme.accent)
            if !part.isEmpty { Text(part).foregroundStyle(DashboardTheme.textTertiary) }
            Text(text).foregroundStyle(DashboardTheme.textSecondary)
        }
        .font(.system(size: 12, design: .monospaced))
    }

    private var routeDeliverSummary: some View {
        let src = shortActor(event.payload?.source_session_key)
        let content = (event.payload?.payload.flatMap { $0.notify_content ?? $0.text } ?? "")
            .replacing("\n", with: " ")
        return HStack(spacing: 4) {
            Text("<-").foregroundStyle(DashboardTheme.fuchsia)
            Text("from:\(src)").foregroundStyle(DashboardTheme.textTertiary)
            Text(content).foregroundStyle(DashboardTheme.textSecondary)
        }
        .font(.system(size: 12, design: .monospaced))
    }

    private var channelMessageSummary: some View {
        let text = (event.payload?.text ?? "").replacing("\n", with: " ")
        return HStack(spacing: 4) {
            Text(">").foregroundStyle(DashboardTheme.blue)
            Text(text).foregroundStyle(DashboardTheme.textSecondary)
        }
        .font(.system(size: 12, design: .monospaced))
    }

    private var agentErrorSummary: some View {
        let err = event.payload?.error ?? event.payload?.text ?? "error"
        return HStack(spacing: 4) {
            Text("!").foregroundStyle(DashboardTheme.red).bold()
            Text(String(err.prefix(200))).foregroundStyle(DashboardTheme.red.opacity(0.85))
        }
        .font(.system(size: 12, design: .monospaced))
    }

    private var fallbackSummary: some View {
        Text(event.type).sysEvtStyle()
    }

    // MARK: - Helpers

    private var timeString: String {
        guard let ts = event.ts else { return "--:--:--.--" }
        return DashboardTheme.formatTime(DashboardTheme.parseISO8601(ts))
    }

    private var rawJSON: String {
        DashboardTheme.prettyJSON(event)
    }

    private var toolDesc: String {
        guard let raw = event.payload?.input_summary, !raw.isEmpty else { return "" }
        guard let data = raw.data(using: .utf8),
              let parsed = try? JSONDecoder().decode([String: String].self, from: data)
        else { return String(raw.prefix(200)) }
        if let desc = parsed["description"], !desc.isEmpty { return String(desc.prefix(200)) }
        if let cmd = parsed["command"] { return String(cmd.prefix(200)) }
        if let fp = parsed["file_path"] { return fp }
        if let pattern = parsed["pattern"] { return pattern }
        if let query = parsed["query"] { return query }
        if let url = parsed["url"] { return url }
        return parsed.values.compactMap { $0 }.first.map { String($0.prefix(200)) } ?? ""
    }

    private func shortActor(_ key: String?) -> String {
        guard let key, !key.isEmpty else { return "system" }
        if key.hasPrefix("meta:subconscious:") { return String(key.dropFirst(18)) }
        if key.hasPrefix("meta:") { return String(key.dropFirst(5)) }
        let parts = key.split(separator: ":")
        if parts.count >= 2 { return "\(parts[0]):\(String(parts.last!.suffix(8)))" }
        return String(key.suffix(12))
    }
}

// MARK: - View Extensions

extension View {
    func sysEvtStyle() -> some View {
        self.font(.system(size: 12, design: .monospaced)).foregroundStyle(DashboardTheme.textTertiary)
    }
}

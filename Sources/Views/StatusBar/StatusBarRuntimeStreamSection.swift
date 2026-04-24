import SwiftUI

struct StatusRuntimeStreamPanel: View {
    let hint: String
    let recentEvents: [SpineEvent]
    let expandedEventIDs: Set<String>
    let onToggle: (String) -> Void

    var body: some View {
        StatusPanelSection(icon: "waveform.path.ecg", title: "Runtime Stream", hint: hint) {
            if recentEvents.isEmpty {
                Text("runtime idle, waiting for new activity")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(ConsolePalette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                streamHero
                if recentEvents.count > 1 {
                    streamTimeline
                }
            }
        }
    }

    @ViewBuilder
    private var streamHero: some View {
        if let event = recentEvents.first {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .center, spacing: 9) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(eventColor(for: event).opacity(0.16))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: heroSymbol(for: event))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(eventColor(for: event))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(heroEyebrow(for: event))
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(eventColor(for: event))
                            Text(latestEventTime(for: event))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(ConsolePalette.secondaryText)
                        }

                        latestEventHeadline(for: event)
                    }

                    Spacer()
                }

                if let detail = latestEventDetail(for: event), !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(ConsolePalette.secondaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(ConsolePalette.panelRaised)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(eventColor(for: event).opacity(0.35), lineWidth: 1)
            )
        }
    }

    private var streamTimeline: some View {
        VStack(spacing: 0) {
            ForEach(Array(recentEvents.dropFirst().prefix(3))) { event in
                EventRowView(
                    event: event,
                    isExpanded: expandedEventIDs.contains(event.id),
                    onToggle: { onToggle(event.id) }
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ConsolePalette.divider, lineWidth: 1)
        )
    }

    private func eventColor(for event: SpineEvent) -> Color {
        DashboardTheme.color(forEventType: event.type)
    }

    private func heroEyebrow(for event: SpineEvent) -> String {
        switch event.type {
        case "agent.tool_use":
            return "CURRENT TOOL"
        case "agent.tool_result":
            return "LATEST RESULT"
        case "agent.error":
            return "ERROR SIGNAL"
        case "agent.result":
            return "AGENT OUTPUT"
        case "channel.message":
            return "CHANNEL FLOW"
        case "route.deliver":
            return "ROUTE DELIVERY"
        default:
            return "LATEST EVENT"
        }
    }

    private func heroSymbol(for event: SpineEvent) -> String {
        switch event.type {
        case "agent.tool_use":
            return "hammer"
        case "agent.tool_result":
            return "checkmark.circle"
        case "agent.error":
            return "exclamationmark.triangle"
        case "agent.result":
            return "sparkles.rectangle.stack"
        case "channel.message":
            return "bubble.left.and.bubble.right"
        case "route.deliver":
            return "arrowshape.turn.up.forward"
        default:
            return "waveform.path.ecg"
        }
    }

    @ViewBuilder
    private func latestEventHeadline(for event: SpineEvent) -> some View {
        Group {
            switch event.type {
            case "agent.tool_use":
                Text(event.payload?.tool_name ?? "tool invocation")
            case "agent.tool_result":
                Text(event.payload?.is_error == true ? "tool execution failed" : "tool execution finished")
            case "agent.error":
                Text("agent reported an error")
            case "agent.result":
                Text("agent produced a result")
            case "channel.message":
                Text("channel delivered a message")
            default:
                Text(event.type)
            }
        }
        .font(.system(size: 15, weight: .semibold, design: .monospaced))
        .foregroundStyle(ConsolePalette.primaryText)
        .lineLimit(1)
    }

    private func latestEventDetail(for event: SpineEvent) -> String? {
        switch event.type {
        case "agent.tool_use":
            return event.payload?.input_summary
        case "agent.tool_result":
            return event.payload?.summary
        case "agent.result", "channel.message":
            return event.payload?.text
        case "agent.error":
            return event.payload?.error ?? event.payload?.text
        case "route.deliver":
            return event.payload?.payload?.notify_content ?? event.payload?.payload?.text
        default:
            return event.payload?.summary ?? event.payload?.text
        }
    }

    private func latestEventTime(for event: SpineEvent) -> String {
        guard let ts = event.ts else { return "now" }
        return DashboardTheme.timeAgo(ts)
    }

    private func shortKey(_ key: String) -> String {
        if key.count <= 20 { return key }
        return String(key.prefix(9)) + "…" + String(key.suffix(7))
    }
}

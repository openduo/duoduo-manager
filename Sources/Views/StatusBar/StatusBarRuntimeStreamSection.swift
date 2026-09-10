import SwiftUI

struct StatusRuntimeStreamPanel: View {
    let hint: String
    let recentEvents: [SpineEvent]
    let expandedEventIDs: Set<String>
    let onToggle: (String) -> Void

    var body: some View {
        StatusPanelSection(title: L10n.Status.runtimeStream, hint: hint) {
            if recentEvents.isEmpty {
                Text("runtime idle, waiting for new activity")
                    .font(.odMono(10))
                    .foregroundStyle(OpenDuo.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                streamHero
                streamTimeline
            }
        }
    }

    /// The latest event: an inset plate whose only emphasis is the mono
    /// eyebrow in the event's ramp colour. Flat — no gradient, no glow.
    @ViewBuilder
    private var streamHero: some View {
        if let event = recentEvents.first {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(heroEyebrow(for: event))
                        .font(.odKicker(9))
                        .foregroundStyle(eventColor(for: event))
                    Text(latestEventTime(for: event))
                        .font(.odMono(9))
                        .foregroundStyle(OpenDuo.textMuted)
                    Spacer()
                    Text(event.type)
                        .font(.odKicker(9))
                        .foregroundStyle(OpenDuo.textKickerNeutral)
                }

                latestEventHeadline(for: event)

                if let detail = latestEventDetail(for: event), !detail.isEmpty {
                    Text(detail)
                        .font(.odMono(10))
                        .foregroundStyle(OpenDuo.textSecondary)
                        .lineLimit(2)
                }

                if let key = event.session_key, !key.isEmpty {
                    Text(shortKey(key))
                        .font(.odMono(9))
                        .foregroundStyle(OpenDuo.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .odInset()
        }
    }

    private var streamTimeline: some View {
        VStack(spacing: 0) {
            ForEach(Array(recentEvents.dropFirst().prefix(2))) { event in
                EventRowView(
                    event: event,
                    isExpanded: expandedEventIDs.contains(event.id),
                    onToggle: { onToggle(event.id) }
                )
            }
        }
        .overlay(alignment: .top) {
            odHRule()
        }
    }

    private func eventColor(for event: SpineEvent) -> Color {
        OpenDuo.color(forEventType: event.type)
    }

    private func heroEyebrow(for event: SpineEvent) -> String {
        switch event.type {
        case "agent.tool_use":
            return L10n.Status.eyebrowCurrentTool
        case "agent.tool_result":
            return L10n.Status.eyebrowLatestResult
        case "agent.error":
            return L10n.Status.eyebrowErrorSignal
        case "agent.result":
            return L10n.Status.eyebrowAgentOutput
        case "channel.message":
            return L10n.Status.eyebrowChannelFlow
        case "route.deliver":
            return L10n.Status.eyebrowRouteDelivery
        default:
            return L10n.Status.eyebrowLatestEvent
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
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(OpenDuo.textStrong)
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
        return SharedPresentationFormatting.timeAgo(ts)
    }

    private func shortKey(_ key: String) -> String {
        if key.count <= 20 { return key }
        return String(key.prefix(9)) + "…" + String(key.suffix(7))
    }
}

import SwiftUI

// MARK: - Sidebar Model

/// A sidebar entry representing a group to view
enum SidebarEntry: Identifiable, Hashable {
    /// Static pages
    case sessions
    case jobs
    /// System events (no session_key)
    case system
    /// Dynamic session_key group (top-level expandable)
    case sessionGroup(key: String)
    /// Sub-item: filter by session + event type
    case sessionTypeItem(key: String, eventType: String)

    var id: String {
        switch self {
        case .sessions: return "__sessions__"
        case .jobs: return "__jobs__"
        case .system: return "__system__"
        case .sessionGroup(let key): return key
        case .sessionTypeItem(let key, let type): return "\(key)__\(type)"
        }
    }
}

struct DashboardView: View {
    @State private var viewModel: DashboardViewModel
    @State private var selectedEntry: SidebarEntry = .sessionGroup(key: "")
    @State private var expandedGroups: Set<String> = []

    init(port: String = "20233") {
        _viewModel = State(initialValue: DashboardViewModel(port: port))
    }

    /// Extract unique session_keys from events, sorted by most recent activity
    private var eventGroups: [String] {
        var seen = Set<String>()
        var keys: [String] = []
        for evt in viewModel.events.reversed() {
            guard let key = evt.session_key, !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            keys.append(key)
        }
        return keys
    }

    /// Events with no session_key (system events like cadence_tick)
    private var systemEvents: [SpineEvent] {
        viewModel.events.filter { $0.session_key == nil || $0.session_key!.isEmpty }
    }

    /// Get event types for a session key — stable order (first seen), with counts
    private func eventTypeCounts(for sessionKey: String) -> [(type: String, count: Int)] {
        let filtered = viewModel.events.filter { $0.session_key == sessionKey }
        var counts: [String: Int] = [:]
        var order: [String] = []
        for evt in filtered {
            if counts[evt.type] == nil { order.append(evt.type) }
            counts[evt.type, default: 0] += 1
        }
        return order.map { (type: $0, count: counts[$0] ?? 0) }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(spacing: 0) {
                mainContent
                bottomStatsBar
            }
        }
        .frame(minWidth: 680, minHeight: 500)
        .background(DashboardTheme.background)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .task { viewModel.startPolling() }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Session groups (expandable)
                    if !eventGroups.isEmpty {
                        sectionLabel("SESSIONS")
                        ForEach(eventGroups, id: \.self) { key in
                            sessionGroupItem(key: key)
                            if expandedGroups.contains(key) {
                                ForEach(eventTypeCounts(for: key), id: \.type) { item in
                                    typeSubItem(sessionKey: key, eventType: item.type, count: item.count)
                                }
                            }
                        }
                    }

                    // Static pages
                    Rectangle()
                        .fill(DashboardTheme.sidebarDivider)
                        .frame(height: 1)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    if !systemEvents.isEmpty {
                        systemItem
                    }
                    staticItem(.sessions)
                    staticItem(.jobs)
                }
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
        }
        .frame(width: 200)
        .background(
            // Extend sidebar color behind traffic lights
            DashboardTheme.sidebarBackground.ignoresSafeArea(edges: .top)
        )
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(DashboardTheme.sidebarHeaderText)
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 4)
    }

    // Top-level session group row
    // Chevron → toggle expand only; name+count area → select only
    private func sessionGroupItem(key: String) -> some View {
        let isExpanded = expandedGroups.contains(key)
        let isSelected = selectedEntry == .sessionGroup(key: key)
        let shortKey = shortSessionKey(key)
        let totalCount = viewModel.events.filter { $0.session_key == key }.count

        return HStack(spacing: 0) {
            // Left accent bar
            Rectangle()
                .fill(isSelected ? DashboardTheme.accent : Color.clear)
                .frame(width: 2)

            // Chevron: expand/collapse only — big enough to hit easily
            Button {
                if isExpanded { expandedGroups.remove(key) } else { expandedGroups.insert(key) }
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DashboardTheme.textSecondary)
                    .frame(width: 28, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Name: select session (show all events)
            Button {
                selectedEntry = .sessionGroup(key: key)
            } label: {
                HStack(spacing: 0) {
                    Text(shortKey)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(isSelected ? DashboardTheme.text : DashboardTheme.sidebarItemText)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Text("\(totalCount)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DashboardTheme.textTertiary)
                        .padding(.trailing, 10)
                }
                .frame(height: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(isSelected ? DashboardTheme.sidebarActive : Color.clear)
    }

    // Sub-item: event type within a session
    private func typeSubItem(sessionKey: String, eventType: String, count: Int) -> some View {
        let entry = SidebarEntry.sessionTypeItem(key: sessionKey, eventType: eventType)
        let isSelected = selectedEntry == entry
        let shortType = shortTypeName(eventType)
        let typeColor = eventTypeColor(eventType)

        return Button {
            selectedEntry = entry
        } label: {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(isSelected ? typeColor : Color.clear)
                    .frame(width: 2)

                // Indent spacer aligning with name (chevron width = 20, plus 2px bar)
                Color.clear.frame(width: 22)

                HStack(spacing: 6) {
                    Text("\u{25CF}")
                        .font(.system(size: 7))
                        .foregroundStyle(typeColor.opacity(0.8))

                    Text(shortType)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(isSelected ? typeColor : typeColor.opacity(0.65))
                        .lineLimit(1)

                    Spacer()

                    Text("\(count)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DashboardTheme.textTertiary)
                        .padding(.trailing, 10)
                }
                .frame(height: 26)
                .contentShape(Rectangle())
            }
            .background(isSelected ? typeColor.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // System events item
    private var systemItem: some View {
        let isSelected = selectedEntry == .system
        return Button {
            selectedEntry = .system
        } label: {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(isSelected ? DashboardTheme.textTertiary : Color.clear)
                    .frame(width: 2)

                HStack(spacing: 6) {
                    Color.clear.frame(width: 20)
                    Text("system")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(isSelected ? DashboardTheme.text : DashboardTheme.sidebarItemText)
                    Spacer()
                    Text("\(systemEvents.count)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DashboardTheme.textTertiary)
                        .padding(.trailing, 10)
                }
                .frame(height: 30)
                .contentShape(Rectangle())
            }
            .background(isSelected ? DashboardTheme.sidebarActive : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // Static page item (Sessions / Jobs)
    private func staticItem(_ entry: SidebarEntry) -> some View {
        let isSelected = selectedEntry == entry
        let label: String
        switch entry {
        case .sessions: label = "sessions"
        case .jobs: label = "jobs"
        default: label = ""
        }

        return Button {
            selectedEntry = entry
        } label: {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(isSelected ? DashboardTheme.accent : Color.clear)
                    .frame(width: 2)

                HStack(spacing: 6) {
                    Color.clear.frame(width: 20)
                    Text(label)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(isSelected ? DashboardTheme.text : DashboardTheme.sidebarItemText)
                    Spacer()
                }
                .frame(height: 30)
                .contentShape(Rectangle())
            }
            .background(isSelected ? DashboardTheme.sidebarActive : Color.clear)
        }
        .buttonStyle(.plain)
    }

    /// Color for an event type — delegates to DashboardTheme
    private func eventTypeColor(_ type: String) -> Color {
        DashboardTheme.color(forEventType: type)
    }

    /// Format session key for display: job:foo.abc12345 → job:foo.abc12345 (last 8 of uuid)
    private func shortSessionKey(_ key: String) -> String {
        if key.hasPrefix("meta:") { return String(key.dropFirst(5)) }
        if key.hasPrefix("job:") {
            let name = String(key.dropFirst(4))
            // keep job name + last 8 chars of the uuid portion
            if let dot = name.lastIndex(of: ".") {
                let base = String(name[..<dot])
                let uid = String(name[name.index(after: dot)...].suffix(8))
                return "job:\(base).\(uid)"
            }
            return "job:\(name)"
        }
        let parts = key.split(separator: ":")
        if parts.count >= 2 {
            return "\(parts[0]):\(String(parts.last!.suffix(8)))"
        }
        return String(key.suffix(16))
    }

    /// Short display name for event type
    private func shortTypeName(_ type: String) -> String {
        // e.g. "agent.tool_use" → "tool_use"
        if let dot = type.lastIndex(of: ".") {
            return String(type[type.index(after: dot)...])
        }
        return type
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        switch selectedEntry {
        case .sessions:
            SessionsContentView(sessions: viewModel.sessions)
        case .jobs:
            JobsContentView(jobs: viewModel.jobs, isJobRunning: viewModel.isJobRunning)
        case .system:
            EventsContentView(events: systemEvents, sessionKey: "system")
        case .sessionGroup(let key):
            let filtered = viewModel.events.filter { $0.session_key == key }
            EventsContentView(events: filtered, sessionKey: key)
        case .sessionTypeItem(let key, let eventType):
            let filtered = viewModel.events.filter { $0.session_key == key && $0.type == eventType }
            EventsContentView(events: filtered, sessionKey: "\(key)  [\(shortTypeName(eventType))]")
        }
    }

    // MARK: - Bottom Stats Bar

    private var bottomStatsBar: some View {
        HStack(spacing: 0) {
            Text(DashboardTheme.formatCost(viewModel.totalCost))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DashboardTheme.text)
            bottomDivider

            Text("tok:\(DashboardTheme.formatTokens(viewModel.totalTokens))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DashboardTheme.text)
            bottomDivider

            Text("tools:\(DashboardTheme.formatTools(viewModel.totalTools))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DashboardTheme.text)

            Spacer()

            // Subconscious partitions
            if let sub = viewModel.subconscious, !sub.partitions.isEmpty {
                HStack(spacing: 6) {
                    Text("sub:")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(DashboardTheme.accent)
                    ForEach(sub.partitions) { part in
                        HStack(spacing: 2) {
                            Text(part.done ? "\u{2713}" : "\u{00B7}")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(part.done ? DashboardTheme.emerald : DashboardTheme.amber)
                                .frame(width: 10)
                            Text(part.name)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(part.done ? DashboardTheme.textSecondary : DashboardTheme.textTertiary)
                        }
                    }
                }
                bottomDivider
            }

            // Health
            HStack(spacing: 5) {
                let isOk = viewModel.health?.gateway == "ok" && (viewModel.health?.meta_session == "ok" || viewModel.health?.meta_session == "starting")
                let isErr = viewModel.health?.gateway == "down" || viewModel.health?.meta_session == "down"
                let color = isOk ? DashboardTheme.emerald : isErr ? DashboardTheme.red : DashboardTheme.amber
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .shadow(color: color.opacity(0.6), radius: 2)
                Text(viewModel.health.map { h in
                    "\(h.gateway == "ok" ? "gw:ok" : "gw:\(h.gateway)") \(h.meta_session == "ok" || h.meta_session == "starting" ? "meta:ok" : "meta:\(h.meta_session)")"
                } ?? "no connection")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(color)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(DashboardTheme.cardBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DashboardTheme.border)
                .frame(height: 1)
        }
    }

    private var bottomDivider: some View {
        Rectangle()
            .fill(DashboardTheme.border)
            .frame(width: 1, height: 12)
            .padding(.horizontal, 10)
    }
}

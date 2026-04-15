import SwiftUI

// MARK: - Sidebar Model

/// A sidebar entry representing a group to view
enum SidebarEntry: Identifiable, Hashable {
    /// Static pages
    case sessions
    case jobs
    case config
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
        case .config: return "__config__"
        case .system: return "__system__"
        case .sessionGroup(let key): return key
        case .sessionTypeItem(let key, let type): return "\(key)__\(type)"
        }
    }
}

struct DashboardView: View {
    @Bindable var store: AppStore
    @State private var selectedEntry: SidebarEntry = .sessionGroup(key: "")
    @State private var expandedGroups: Set<String> = []

    private var dashboardPresentation: DashboardPresentationBundle {
        DashboardPresentationMapper.make(store: store)
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
        .background(DashboardTheme.background.ignoresSafeArea(edges: .top))
        .task { store.startDashboardPolling() }
        .onDisappear { store.stopDashboardPolling() }
        .onChange(of: selectedEntry) { _, new in
            if new == .config { Task { await store.fetchConfig() } }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !dashboardPresentation.sidebarGroups.isEmpty {
                        sectionLabel("SESSIONS")
                        ForEach(dashboardPresentation.sidebarGroups) { group in
                            sessionGroupItem(group)
                            if expandedGroups.contains(group.key) {
                                ForEach(group.eventTypes) { item in
                                    typeSubItem(sessionKey: group.key, item: item)
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

                    if !dashboardPresentation.systemEvents.isEmpty {
                        systemItem
                    }
                    staticItem(.sessions)
                    staticItem(.jobs)
                    staticItem(.config)
                }
                .padding(.top, 4)
                .padding(.bottom, 8)
            }

            // Bottom: daemon URL
            Text(store.runtime.daemonConfig.daemonURL)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(DashboardTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
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
    private func sessionGroupItem(_ group: DashboardSidebarGroupPresentation) -> some View {
        let isExpanded = expandedGroups.contains(group.key)
        let isSelected = selectedEntry == .sessionGroup(key: group.key)

        return HStack(spacing: 0) {
            // Left accent bar
            Rectangle()
                .fill(isSelected ? DashboardTheme.accent : Color.clear)
                .frame(width: 2)

            // Chevron: expand/collapse only — big enough to hit easily
            Button {
                if isExpanded { expandedGroups.remove(group.key) } else { expandedGroups.insert(group.key) }
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
                selectedEntry = .sessionGroup(key: group.key)
            } label: {
                HStack(spacing: 0) {
                    Text(group.label)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(isSelected ? DashboardTheme.text : DashboardTheme.sidebarItemText)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Text("\(group.count)")
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
    private func typeSubItem(sessionKey: String, item: DashboardEventTypePresentation) -> some View {
        let entry = SidebarEntry.sessionTypeItem(key: sessionKey, eventType: item.type)
        let isSelected = selectedEntry == entry

        return Button {
            selectedEntry = entry
        } label: {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(isSelected ? item.color : Color.clear)
                    .frame(width: 2)

                // Indent spacer aligning with name (chevron width = 20, plus 2px bar)
                Color.clear.frame(width: 22)

                HStack(spacing: 6) {
                    Text("\u{25CF}")
                        .font(.system(size: 7))
                        .foregroundStyle(item.color.opacity(0.8))

                    Text(item.shortName)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(isSelected ? item.color : item.color.opacity(0.65))
                        .lineLimit(1)

                    Spacer()

                    Text("\(item.count)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DashboardTheme.textTertiary)
                        .padding(.trailing, 10)
                }
                .frame(height: 26)
                .contentShape(Rectangle())
            }
            .background(isSelected ? item.color.opacity(0.08) : Color.clear)
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
                    Text("\(dashboardPresentation.systemEvents.count)")
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
        case .config: label = "config"
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

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        switch selectedEntry {
        case .sessions:
            SessionsContentView(sessions: store.dashboard.sessions)
        case .config:
            ConfigContentView(config: store.dashboard.config)
        case .jobs:
            JobsContentView(jobs: store.dashboard.jobs, isJobRunning: store.isJobRunning)
        case .system:
            EventsContentView(events: dashboardPresentation.systemEvents, sessionKey: "system")
        case .sessionGroup(let key):
            let filtered = store.dashboard.events.filter { $0.session_key == key }
            EventsContentView(events: filtered, sessionKey: key)
        case .sessionTypeItem(let key, let eventType):
            let filtered = store.dashboard.events.filter { $0.session_key == key && $0.type == eventType }
            EventsContentView(events: filtered, sessionKey: "\(key)  [\(DashboardPresentationMapper.shortTypeName(eventType))]")
        }
    }

    // MARK: - Bottom Stats Bar

    private var bottomStatsBar: some View {
        HStack(spacing: 0) {
            Text(dashboardPresentation.bottomStats.costText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DashboardTheme.text)
            bottomDivider

            Text(dashboardPresentation.bottomStats.tokenText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DashboardTheme.text)
            bottomDivider

            Text(dashboardPresentation.bottomStats.cacheText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DashboardTheme.text)
            bottomDivider

            Text(dashboardPresentation.bottomStats.toolText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DashboardTheme.text)

            Spacer()

            if !dashboardPresentation.bottomStats.subconsciousItems.isEmpty {
                HStack(spacing: 6) {
                    Text("sub:")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(DashboardTheme.accent)
                    ForEach(dashboardPresentation.bottomStats.subconsciousItems) { item in
                        HStack(spacing: 2) {
                            Text(item.marker)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(item.markerColor)
                                .frame(width: 10)
                            Text(item.name)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(item.textColor)
                        }
                    }
                }
                bottomDivider
            }

            HStack(spacing: 5) {
                Circle()
                    .fill(dashboardPresentation.bottomStats.healthColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: dashboardPresentation.bottomStats.healthColor.opacity(0.6), radius: 2)
                Text(dashboardPresentation.bottomStats.healthText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(dashboardPresentation.bottomStats.healthColor)
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

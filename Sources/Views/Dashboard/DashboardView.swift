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
            odVRule()
            VStack(spacing: 0) {
                mainContent
                bottomStatsBar
            }
        }
        .frame(minWidth: 680, minHeight: 500)
        .background(OpenDuo.page.ignoresSafeArea(edges: .top))
        .odChrome()
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
                        sectionLabel(L10n.Dashboard.activeSessionsHeader)
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
                    odHRule()
                        .padding(.horizontal, 12)
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
                .font(.odMono(9))
                .foregroundStyle(OpenDuo.textMuted)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
        }
        .frame(width: 200)
        .background(
            // Extend sidebar color behind traffic lights
            OpenDuo.surfacePanel.ignoresSafeArea(edges: .top)
        )
    }

    private func sectionLabel(_ title: String) -> some View {
        ODKicker(text: title, tint: OpenDuo.textKickerNeutral)
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
            // Left brand bar marks the active selection
            Rectangle()
                .fill(isSelected ? OpenDuo.brand : Color.clear)
                .frame(width: 2)

            // Chevron: expand/collapse only — big enough to hit easily
            Button {
                if isExpanded { expandedGroups.remove(group.key) } else { expandedGroups.insert(group.key) }
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(OpenDuo.textMuted)
                    .frame(width: 24, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Name: select session (show all events)
            Button {
                selectedEntry = .sessionGroup(key: group.key)
            } label: {
                HStack(spacing: 0) {
                    Text(group.label)
                        .font(.odMono(12))
                        .foregroundStyle(isSelected ? OpenDuo.textStrong : OpenDuo.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Text("\(group.count)")
                        .font(.odMono(10))
                        .foregroundStyle(OpenDuo.textFaint)
                        .padding(.trailing, 10)
                }
                .frame(height: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(isSelected ? OpenDuo.surfaceInset : Color.clear)
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
                    ODStateTick(tint: item.color.opacity(0.8), size: 5)

                    Text(item.shortName)
                        .font(.odMono(11))
                        .foregroundStyle(isSelected ? item.color : item.color.opacity(0.7))
                        .lineLimit(1)

                    Spacer()

                    Text("\(item.count)")
                        .font(.odMono(10))
                        .foregroundStyle(OpenDuo.textFaint)
                        .padding(.trailing, 10)
                }
                .frame(height: 26)
                .contentShape(Rectangle())
            }
            .background(isSelected ? OpenDuo.surfaceInset : Color.clear)
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
                    .fill(isSelected ? OpenDuo.textSecondary : Color.clear)
                    .frame(width: 2)

                HStack(spacing: 6) {
                    Color.clear.frame(width: 20)
                    Text("system")
                        .font(.odMono(12))
                        .foregroundStyle(isSelected ? OpenDuo.textStrong : OpenDuo.textSecondary)
                    Spacer()
                    Text("\(dashboardPresentation.systemEvents.count)")
                        .font(.odMono(10))
                        .foregroundStyle(OpenDuo.textFaint)
                        .padding(.trailing, 10)
                }
                .frame(height: 30)
                .contentShape(Rectangle())
            }
            .background(isSelected ? OpenDuo.surfaceInset : Color.clear)
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
                    .fill(isSelected ? OpenDuo.brand : Color.clear)
                    .frame(width: 2)

                HStack(spacing: 6) {
                    Color.clear.frame(width: 20)
                    Text(label)
                        .font(.odMono(12))
                        .foregroundStyle(isSelected ? OpenDuo.textStrong : OpenDuo.textSecondary)
                    Spacer()
                }
                .frame(height: 30)
                .contentShape(Rectangle())
            }
            .background(isSelected ? OpenDuo.surfaceInset : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        switch selectedEntry {
        case .sessions:
            SessionsContentView(store: store)
        case .config:
            ConfigContentView(config: store.dashboard.config)
        case .jobs:
            JobsContentView(jobs: store.dashboard.jobs, isJobRunning: store.isJobRunning)
        case .system:
            EventsContentView(events: dashboardPresentation.systemEvents, sessionKey: "system")
                .id("system")
        case .sessionGroup(let key):
            let filtered = store.dashboard.events.filter { $0.session_key == key }
            EventsContentView(events: filtered, sessionKey: key)
                .id("session:\(key)")
        case .sessionTypeItem(let key, let eventType):
            let filtered = store.dashboard.events.filter { $0.session_key == key && $0.type == eventType }
            EventsContentView(events: filtered, sessionKey: "\(key)  [\(DashboardPresentationMapper.shortTypeName(eventType))]")
                .id("session-type:\(key):\(eventType)")
        }
    }

    // MARK: - Bottom Stats Bar

    private var bottomStatsBar: some View {
        HStack(spacing: 0) {
            Text(dashboardPresentation.bottomStats.costText)
                .font(.odMono(10))
                .foregroundStyle(OpenDuo.textPrimary)
            bottomDivider

            Text(dashboardPresentation.bottomStats.tokenText)
                .font(.odMono(10))
                .foregroundStyle(OpenDuo.textPrimary)
            bottomDivider

            Text(dashboardPresentation.bottomStats.cacheText)
                .font(.odMono(10))
                .foregroundStyle(OpenDuo.textPrimary)
            bottomDivider

            Text(dashboardPresentation.bottomStats.toolText)
                .font(.odMono(10))
                .foregroundStyle(OpenDuo.textPrimary)

            if !dashboardPresentation.bottomStats.subconsciousItems.isEmpty {
                bottomDivider
                HStack(spacing: 6) {
                    Text("sub:")
                        .font(.odMono(9))
                        .foregroundStyle(OpenDuo.textKicker)
                        .fixedSize(horizontal: true, vertical: false)
                    ForEach(dashboardPresentation.bottomStats.subconsciousItems) { item in
                        HStack(spacing: 2) {
                            Text(item.marker)
                                .font(.odMono(9))
                                .foregroundStyle(item.markerColor)
                                .frame(width: 10)
                            Text(item.name)
                                .font(.odMono(9))
                                .foregroundStyle(item.textColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .truncationMode(.middle)
                        }
                    }
                }
                bottomDivider
            } else {
                Spacer()
            }

            HStack(spacing: 5) {
                ODSignalDot(tint: dashboardPresentation.bottomStats.healthColor)
                Text(dashboardPresentation.bottomStats.healthText)
                    .font(.odMono(10))
                    .foregroundStyle(dashboardPresentation.bottomStats.healthColor)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(OpenDuo.surfacePanel)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(OpenDuo.borderHairline)
                .frame(height: 1)
        }
    }

    private var bottomDivider: some View {
        Rectangle()
            .fill(OpenDuo.borderSubtle)
            .frame(width: 1, height: 12)
            .padding(.horizontal, 10)
    }
}

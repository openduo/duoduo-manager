import SwiftUI

struct SessionsContentView: View {
    @Bindable var store: AppStore
    @State private var aliasTarget: SessionRegistryEntry?
    @State private var aliasName = ""
    @State private var notifyTarget: SessionRegistryEntry?
    @State private var notifyMessage = ""
    @State private var archiveTarget: SessionRegistryEntry?

    private var activeByKey: [String: SessionInfo] {
        Dictionary(store.dashboard.sessions.map { ($0.session_key, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    private var allSessions: [SessionRegistryEntry] {
        let listed = store.dashboard.allSessions
        guard !listed.isEmpty else {
            return store.dashboard.sessions.map(SessionRegistryEntry.fromActive)
        }

        var byKey = Dictionary(listed.map { ($0.session_key, $0) }, uniquingKeysWith: { _, latest in latest })
        for active in store.dashboard.sessions where byKey[active.session_key] == nil {
            byKey[active.session_key] = .fromActive(active)
        }
        return byKey.values.sorted { lhs, rhs in
            let lhsDate = lhs.last_event_at ?? ""
            let rhsDate = rhs.last_event_at ?? ""
            if lhsDate != rhsDate { return lhsDate > rhsDate }
            return lhs.session_key < rhs.session_key
        }
    }

    private var workSessions: [SessionRegistryEntry] {
        allSessions.filter { entry in
            !isJobSession(entry) && !isMetaSession(entry)
        }
    }

    private var jobSessions: [SessionRegistryEntry] {
        allSessions.filter(isJobSession)
    }

    private var metaSessions: [SessionRegistryEntry] {
        allSessions.filter { !isJobSession($0) && isMetaSession($0) }
    }

    private func isJobSession(_ entry: SessionRegistryEntry) -> Bool {
        entry.session_key.hasPrefix("job:") || entry.kind == "job"
    }

    private func isMetaSession(_ entry: SessionRegistryEntry) -> Bool {
        entry.session_key.hasPrefix("meta:") || entry.plane == "meta"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("> ")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(DashboardTheme.accent)
                Text(L10n.Dashboard.sessionsTitle)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(DashboardTheme.text)
                Text("  [\(allSessions.count)]")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(DashboardTheme.textTertiary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Rectangle()
                .fill(DashboardTheme.border)
                .frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if allSessions.isEmpty {
                        Text(L10n.Dashboard.noSessions)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(DashboardTheme.textTertiary)
                            .padding(40)
                    } else {
                        if !workSessions.isEmpty {
                            groupLabel(L10n.Dashboard.workSessions)
                            ForEach(workSessions) { session in
                                sessionRow(session)
                            }
                        }
                        if !jobSessions.isEmpty {
                            groupLabel(L10n.Dashboard.jobSessions)
                            ForEach(jobSessions) { session in
                                sessionRow(session)
                            }
                        }
                        if !metaSessions.isEmpty {
                            groupLabel(L10n.Dashboard.metaSessions)
                            ForEach(metaSessions) { session in
                                sessionRow(session)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $aliasTarget) { target in
            sessionAliasSheet(target)
        }
        .sheet(item: $notifyTarget) { target in
            sessionNotifySheet(target)
        }
        .confirmationDialog(
            L10n.Dashboard.archiveSessionTitle,
            isPresented: Binding(
                get: { archiveTarget != nil },
                set: { if !$0 { archiveTarget = nil } }
            ),
            titleVisibility: .visible,
            presenting: archiveTarget
        ) { target in
            Button(L10n.Dashboard.archive, role: .destructive) {
                store.archiveSession(target.session_key)
                archiveTarget = nil
            }
            Button(L10n.Config.cancel, role: .cancel) {
                archiveTarget = nil
            }
        } message: { target in
            Text(target.display_name ?? target.session_key)
        }
    }

    private func groupLabel(_ title: String) -> some View {
        Text("# \(title)")
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(DashboardTheme.textTertiary)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    private func sessionRow(_ s: SessionRegistryEntry) -> some View {
        let active = activeByKey[s.session_key]
        let status = active?.status ?? (s.orphan == true ? "orphan" : "registered")
        let color: Color = switch status {
        case "active": DashboardTheme.emerald
        case "error":  DashboardTheme.red
        case "ended":  DashboardTheme.textTertiary
        case "orphan": DashboardTheme.amber
        default:       DashboardTheme.blue
        }

        let displayName = s.display_name ?? s.session_key

        return HStack(spacing: 0) {
            // Left accent bar
            Rectangle()
                .fill(color)
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(DashboardTheme.text)
                        .lineLimit(1)
                    if s.display_name != nil {
                        Text(s.session_key)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(DashboardTheme.textTertiary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 8) {
                    Text("[\(status)]")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(color)

                    if let health = active?.health {
                        Text("health:\(health)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(DashboardTheme.textTertiary)
                    }

                    if let lastEvent = s.last_event_at {
                        Text("last:\(DashboardTheme.timeAgo(lastEvent))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(DashboardTheme.textTertiary)
                    }

                    if let kind = s.kind {
                        Text("kind:\(kind)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(DashboardTheme.textTertiary)
                    }

                    if let cwd = s.cwd {
                        Text("cwd:\(cwd)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(DashboardTheme.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                if let lastError = s.lastErrorText {
                    Text("err: \(lastError)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(DashboardTheme.red)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Spacer()

            HStack(spacing: 4) {
                Button {
                    aliasTarget = s
                    aliasName = s.display_name ?? ""
                } label: {
                    Image(systemName: "tag")
                }
                .help(L10n.Dashboard.alias)

                Button {
                    notifyTarget = s
                    notifyMessage = ""
                } label: {
                    Image(systemName: "paperplane")
                }
                .help(L10n.Dashboard.notify)

                Button {
                    archiveTarget = s
                } label: {
                    Image(systemName: "archivebox")
                }
                .help(L10n.Dashboard.archive)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .foregroundStyle(DashboardTheme.textSecondary)
            .padding(.trailing, 10)
        }
        .background(DashboardTheme.cardBackground)
        .padding(.bottom, 2)
    }

    private func sessionAliasSheet(_ target: SessionRegistryEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Dashboard.sessionAliasTitle)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(DashboardTheme.text)
            Text(target.session_key)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(DashboardTheme.textTertiary)
                .lineLimit(2)
                .textSelection(.enabled)
            TextField(L10n.Dashboard.displayNamePlaceholder, text: $aliasName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button(L10n.Dashboard.clearAlias) {
                    store.aliasSession(target.session_key, name: nil)
                    aliasTarget = nil
                }
                Spacer()
                Button(L10n.Config.cancel) {
                    aliasTarget = nil
                }
                Button(L10n.Config.save) {
                    store.aliasSession(target.session_key, name: aliasName)
                    aliasTarget = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 420)
        .background(DashboardTheme.background)
    }

    private func sessionNotifySheet(_ target: SessionRegistryEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Dashboard.notifySessionTitle)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(DashboardTheme.text)
            Text(target.display_name ?? target.session_key)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(DashboardTheme.textTertiary)
                .lineLimit(2)
                .textSelection(.enabled)
            TextEditor(text: $notifyMessage)
                .font(.system(size: 12, design: .monospaced))
                .frame(height: 120)
                .scrollContentBackground(.hidden)
                .background(DashboardTheme.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(DashboardTheme.border, lineWidth: 1)
                }
            HStack {
                Spacer()
                Button(L10n.Config.cancel) {
                    notifyTarget = nil
                }
                Button(L10n.Dashboard.send) {
                    store.notifySession(target.session_key, message: notifyMessage)
                    notifyTarget = nil
                }
                .buttonStyle(.borderedProminent)
                .disabled(notifyMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 460)
        .background(DashboardTheme.background)
    }

}

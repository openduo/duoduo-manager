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
                ODKicker(text: L10n.Dashboard.sessionsTitle, tint: OpenDuo.textKicker)
                Text("  [\(allSessions.count)]")
                    .font(.odMono(10))
                    .foregroundStyle(OpenDuo.textFaint)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Rectangle()
                .fill(OpenDuo.borderHairline)
                .frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if allSessions.isEmpty {
                        Text(L10n.Dashboard.noSessions)
                            .font(.odMono(11))
                            .foregroundStyle(OpenDuo.textMuted)
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
        ODKicker(text: title, tint: OpenDuo.textKickerNeutral)
            .padding(.top, 12)
            .padding(.bottom, 6)
    }

    private func sessionRow(_ s: SessionRegistryEntry) -> some View {
        let active = activeByKey[s.session_key]
        let status = active?.status ?? (s.orphan == true ? "orphan" : "registered")
        let color: Color = switch status {
        case "active": OpenDuo.ok
        case "error":  OpenDuo.alert
        case "ended":  OpenDuo.textMuted
        case "orphan": OpenDuo.attention
        default:       OpenDuo.cyan200
        }

        let displayName = s.display_name ?? s.session_key
        let runtimeCaption = SharedPresentationFormatting.sessionRuntimeCaption(
            runtime: active?.runtime ?? s.runtime,
            model: active?.model ?? s.model
        )

        return HStack(spacing: 0) {
            // Square state marker — the row's only colour
            ODStateTick(tint: color, size: 7)
                .padding(.trailing, 10)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(.odMono(12, weight: .medium))
                        .foregroundStyle(OpenDuo.textPrimary)
                        .lineLimit(1)
                    if let runtimeCaption {
                        Text("[\(runtimeCaption)]")
                            .font(.odMono(9))
                            .foregroundStyle(OpenDuo.textFaint)
                    }
                    if s.display_name != nil {
                        Text(s.session_key)
                            .font(.odMono(9))
                            .foregroundStyle(OpenDuo.textFaint)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 8) {
                    Text(status)
                        .font(.odMono(9))
                        .foregroundStyle(color)

                    if let health = active?.health {
                        Text("health:\(health)")
                            .font(.odMono(9))
                            .foregroundStyle(OpenDuo.textMuted)
                    }

                    if let lastEvent = s.last_event_at {
                        Text("last:\(SharedPresentationFormatting.timeAgo(lastEvent))")
                            .font(.odMono(9))
                            .foregroundStyle(OpenDuo.textMuted)
                    }

                    if let kind = s.kind {
                        Text("kind:\(kind)")
                            .font(.odMono(9))
                            .foregroundStyle(OpenDuo.textMuted)
                    }

                    if let cwd = s.cwd {
                        Text("cwd:\(cwd)")
                            .font(.odMono(9))
                            .foregroundStyle(OpenDuo.textMuted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                if let lastError = s.lastErrorText {
                    Text("err: \(lastError)")
                        .font(.odMono(9))
                        .foregroundStyle(OpenDuo.alert)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Button {
                    aliasTarget = s
                    aliasName = s.display_name ?? ""
                } label: {
                    Image(systemName: "tag")
                        .font(.system(size: 10))
                }
                .help(L10n.Dashboard.alias)

                Button {
                    notifyTarget = s
                    notifyMessage = ""
                } label: {
                    Image(systemName: "paperplane")
                        .font(.system(size: 10))
                }
                .help(L10n.Dashboard.notify)

                Button {
                    archiveTarget = s
                } label: {
                    Image(systemName: "archivebox")
                        .font(.system(size: 10))
                }
                .help(L10n.Dashboard.archive)
            }
            .buttonStyle(ODIconButtonStyle())
            .padding(.trailing, 10)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(OpenDuo.borderHairline).frame(height: 1).padding(.horizontal, 12)
        }
        .background(OpenDuo.surface)
    }

    private func sessionAliasSheet(_ target: SessionRegistryEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ODKicker(text: L10n.Dashboard.sessionAliasTitle, tint: OpenDuo.textKicker)
            Text(target.session_key)
                .font(.odMono(9))
                .foregroundStyle(OpenDuo.textMuted)
                .lineLimit(2)
                .textSelection(.enabled)
            TextField(L10n.Dashboard.displayNamePlaceholder, text: $aliasName)
                .textFieldStyle(.plain)
                .font(.odMono(12))
                .foregroundStyle(OpenDuo.textPrimary)
                .odField(horizontal: 10, vertical: 7)
            HStack {
                Button(L10n.Dashboard.clearAlias) {
                    store.aliasSession(target.session_key, name: nil)
                    aliasTarget = nil
                }
                .buttonStyle(ODOutlineButtonStyle())
                Spacer()
                Button(L10n.Config.cancel) {
                    aliasTarget = nil
                }
                .buttonStyle(ODOutlineButtonStyle())
                Button(L10n.Config.save) {
                    store.aliasSession(target.session_key, name: aliasName)
                    aliasTarget = nil
                }
                .buttonStyle(ODPrimaryButtonStyle())
            }
        }
        .padding(16)
        .frame(width: 420)
        .background(OpenDuo.page)
        .odChrome()
    }

    private func sessionNotifySheet(_ target: SessionRegistryEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ODKicker(text: L10n.Dashboard.notifySessionTitle, tint: OpenDuo.textKicker)
            Text(target.display_name ?? target.session_key)
                .font(.odMono(9))
                .foregroundStyle(OpenDuo.textMuted)
                .lineLimit(2)
                .textSelection(.enabled)
            TextEditor(text: $notifyMessage)
                .font(.odMono(11))
                .foregroundStyle(OpenDuo.textPrimary)
                .frame(height: 120)
                .scrollContentBackground(.hidden)
                .odField(horizontal: 0, vertical: 0)
            HStack {
                Spacer()
                Button(L10n.Config.cancel) {
                    notifyTarget = nil
                }
                .buttonStyle(ODOutlineButtonStyle())
                Button(L10n.Dashboard.send) {
                    store.notifySession(target.session_key, message: notifyMessage)
                    notifyTarget = nil
                }
                .buttonStyle(ODPrimaryButtonStyle())
                .disabled(notifyMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 460)
        .background(OpenDuo.page)
        .odChrome()
    }

}

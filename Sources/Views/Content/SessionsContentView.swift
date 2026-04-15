import SwiftUI

struct SessionsContentView: View {
    let sessions: [SessionInfo]

    private var cortexSessions: [SessionInfo] {
        sessions.filter { !$0.session_key.hasPrefix("meta:") && !$0.session_key.hasPrefix("job:") }
    }

    private var metaSessions: [SessionInfo] {
        sessions.filter { $0.session_key.hasPrefix("meta:") }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("> ")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(DashboardTheme.accent)
                Text("sessions")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(DashboardTheme.text)
                Text("  [\(sessions.count)]")
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
                    if sessions.isEmpty {
                        Text("no active sessions")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(DashboardTheme.textTertiary)
                            .padding(40)
                    } else {
                        if !cortexSessions.isEmpty {
                            groupLabel("cortex")
                            ForEach(cortexSessions) { session in
                                sessionRow(session)
                            }
                        }
                        if !metaSessions.isEmpty {
                            groupLabel("meta")
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
    }

    private func groupLabel(_ title: String) -> some View {
        Text("# \(title)")
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(DashboardTheme.textTertiary)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    private func sessionRow(_ s: SessionInfo) -> some View {
        let color: Color = switch s.status {
        case "active": DashboardTheme.emerald
        case "error":  DashboardTheme.red
        case "ended":  DashboardTheme.textTertiary
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
                    Text("[\(s.status)]")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(color)

                    if let health = s.health {
                        Text("health:\(health)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(DashboardTheme.textTertiary)
                    }

                    if let lastEvent = s.last_event_at {
                        Text("last:\(DashboardTheme.timeAgo(lastEvent))")
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

                if let lastError = s.last_error {
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
        }
        .background(DashboardTheme.cardBackground)
        .padding(.bottom, 2)
    }

}

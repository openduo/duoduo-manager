import SwiftUI

struct StatusExecutionPanel: View {
    let hint: String
    let sessionCaption: String
    let jobCaption: String
    let sessionRows: [SummaryRowData]
    let jobRows: [SummaryRowData]

    var body: some View {
        StatusPanelSection(title: L10n.Status.executionBoard, hint: hint) {
            HStack(alignment: .top, spacing: 0) {
                summarySection(
                    title: "sessions",
                    caption: sessionCaption,
                    rows: sessionRows,
                    emptyText: "no active sessions"
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                odVRule()
                    .padding(.horizontal, 10)

                summarySection(
                    title: "jobs",
                    caption: jobCaption,
                    rows: jobRows,
                    emptyText: "no jobs running"
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func summarySection(title: String, caption: String, rows: [SummaryRowData], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                ODKicker(text: title, tint: OpenDuo.textSecondary, size: 9)
                Spacer()
                Text(caption)
                    .font(.odMono(9))
                    .foregroundStyle(OpenDuo.textMuted)
            }

            if rows.isEmpty {
                Text(emptyText)
                    .font(.odMono(10))
                    .foregroundStyle(OpenDuo.textMuted)
                    .padding(.vertical, 2)
            } else {
                ForEach(Array(rows.prefix(3)), id: \.title) { row in
                    HStack(spacing: 8) {
                        ODStateTick(tint: row.tint, size: 5)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                                .font(.odMono(10, weight: .medium))
                                .foregroundStyle(OpenDuo.textPrimary)
                                .lineLimit(1)
                            Text(row.detail)
                                .font(.odMono(9))
                                .foregroundStyle(OpenDuo.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(row.state)
                            .font(.odMono(9, weight: .medium))
                            .foregroundStyle(row.tint)
                    }
                }
            }
        }
        .padding(9)
        .odInset()
    }
}

struct StatusFooterBar: View {
    let preferredTerminalApp: PreferredTerminalApp
    let onDashboard: () -> Void
    let onOnboard: () -> Void
    let onReader: () -> Void
    let onTerminal: () -> Void
    let onSelectTerminalApp: (PreferredTerminalApp) -> Void
    let onQuit: () -> Void

    @State private var installedTerminalApps: [PreferredTerminalApp] = []

    private func refreshInstalledTerminalApps() {
        installedTerminalApps = PreferredTerminalApp.allCases.filter { $0.isInstalled }
    }

    var body: some View {
        HStack(spacing: 8) {
            footerButton(title: "ATC", systemImage: "square.grid.2x2", action: onDashboard)
            footerButton(title: "Reader", systemImage: "book.closed", action: onReader)
            footerButton(title: "Onboard", systemImage: "checklist", action: onOnboard)
            terminalControl
                .onAppear { refreshInstalledTerminalApps() }

            Spacer(minLength: 8)

            footerButton(title: L10n.Status.quit, systemImage: "power", action: onQuit)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(OpenDuo.surfacePanel)
        .overlay(alignment: .top) {
            Rectangle().fill(OpenDuo.borderHairline).frame(height: 1)
        }
    }

    @ViewBuilder
    private var terminalControl: some View {
        if installedTerminalApps.count <= 1 {
            footerButton(title: preferredTerminalApp.title, systemImage: "terminal", action: onTerminal)
        } else {
            HStack(spacing: 0) {
                Button(action: onTerminal) {
                    footerButtonLabel(title: preferredTerminalApp.title, systemImage: "terminal")
                        .padding(.leading, 8)
                        .padding(.trailing, 5)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(OpenDuo.borderInput)
                    .frame(width: 1, height: 14)

                Menu {
                    ForEach(installedTerminalApps, id: \.rawValue) { app in
                        Button {
                            onSelectTerminalApp(app)
                        } label: {
                            if preferredTerminalApp == app {
                                Label(app.title, systemImage: "checkmark")
                            } else {
                                Text(app.title)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(OpenDuo.textMuted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
            }
            .background(OpenDuo.surfaceInset)
            .overlay(Rectangle().stroke(OpenDuo.borderInput, lineWidth: 1))
            .help("Open in \(preferredTerminalApp.title)")
        }
    }

    private func footerButtonLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .medium))
            Text(title)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(OpenDuo.textSecondary)
    }

    private func footerButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            footerButtonLabel(title: title, systemImage: systemImage)
        }
        .buttonStyle(ODOutlineButtonStyle())
    }
}

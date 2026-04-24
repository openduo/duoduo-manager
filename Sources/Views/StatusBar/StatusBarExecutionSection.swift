import SwiftUI

struct StatusExecutionPanel: View {
    let hint: String
    let sessionCaption: String
    let jobCaption: String
    let sessionRows: [SummaryRowData]
    let jobRows: [SummaryRowData]

    var body: some View {
        StatusPanelSection(icon: "square.stack.3d.up", title: "Execution Board", hint: hint) {
            HStack(alignment: .top, spacing: 10) {
                summarySection(
                    title: "sessions",
                    caption: sessionCaption,
                    rows: sessionRows,
                    emptyText: "no active sessions"
                )

                summarySection(
                    title: "jobs",
                    caption: jobCaption,
                    rows: jobRows,
                    emptyText: "no jobs running"
                )
            }
        }
    }

    private func summarySection(title: String, caption: String, rows: [SummaryRowData], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: title == "sessions" ? "person.2.fill" : "shippingbox.fill")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(ConsolePalette.mutedText)
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(ConsolePalette.secondaryText)
                Spacer()
                Text(caption)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(ConsolePalette.mutedText)
            }

            if rows.isEmpty {
                Text(emptyText)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(ConsolePalette.mutedText)
                    .padding(.vertical, 2)
            } else {
                ForEach(Array(rows.prefix(3)), id: \.title) { row in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(row.tint)
                            .frame(width: 6, height: 6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(ConsolePalette.primaryText)
                                .lineLimit(1)
                            Text(row.detail)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(ConsolePalette.secondaryText)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(row.state)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(row.tint)
                    }
                }
            }
        }
        .padding(9)
        .background(ConsolePalette.panelRaised)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ConsolePalette.divider, lineWidth: 1)
        )
    }
}

struct StatusFooterBar: View {
    let statusMessage: String?
    let statusIsError: Bool
    let onDashboard: () -> Void
    let onOnboard: () -> Void
    let onReader: () -> Void
    let onTerminal: () -> Void
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            footerButton(title: "ATC", systemImage: "square.grid.2x2", action: onDashboard)
            footerButton(title: "Reader", systemImage: "book.closed", action: onReader)
            footerButton(title: "Onboard", systemImage: "checklist", action: onOnboard)
            footerButton(title: "Terminal", systemImage: "terminal", action: onTerminal)

            Spacer(minLength: 8)

            if let statusMessage, !statusMessage.isEmpty {
                footerStatusMessage(statusMessage)
            }

            footerButton(title: L10n.Status.quit, systemImage: "power", action: onQuit)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(ConsolePalette.panel)
    }

    private func footerButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(ConsolePalette.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(ConsolePalette.panelRaised)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func footerStatusMessage(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(message)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(statusIsError ? ConsolePalette.critical : ConsolePalette.secondaryText)
        .frame(maxWidth: 128, alignment: .trailing)
        .help(message)
    }
}

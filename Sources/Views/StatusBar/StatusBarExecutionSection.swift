import SwiftUI

struct StatusExecutionPanel: View {
    let hint: String
    let sessionCaption: String
    let jobCaption: String
    let sessionRows: [SummaryRowData]
    let jobRows: [SummaryRowData]

    var body: some View {
        StatusPanelSection(icon: "square.stack.3d.up", title: "Execution Board", hint: hint) {
            HStack(alignment: .top, spacing: 12) {
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
        VStack(alignment: .leading, spacing: 8) {
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
                    .padding(.vertical, 4)
            } else {
                ForEach(rows, id: \.title) { row in
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
        .padding(10)
        .background(ConsolePalette.panelRaised)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ConsolePalette.divider, lineWidth: 1)
        )
    }
}

struct StatusFooterBar: View {
    let costValue: String
    let tokenValue: String
    let cacheValue: String
    let toolsValue: String
    let onDashboard: () -> Void
    let onReader: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                footerMetric(title: "COST", value: costValue, icon: "dollarsign.circle")
                footerDivider
                footerMetric(title: "TOK", value: tokenValue, icon: "circle.hexagongrid")
                footerDivider
                footerMetric(title: "CACHE", value: cacheValue, icon: "externaldrive")
                footerDivider
                footerMetric(title: "TOOLS", value: toolsValue, icon: "wrench.and.screwdriver")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider().overlay(ConsolePalette.divider)

            HStack(spacing: 8) {
                footerButton(title: "ATC", systemImage: "square.grid.2x2", action: onDashboard)
                footerButton(title: "Reader", systemImage: "book.closed", action: onReader)
                Spacer()
                footerButton(title: L10n.Status.quit, systemImage: "power", action: onQuit)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(ConsolePalette.panel)
    }

    private var footerDivider: some View {
        Rectangle()
            .fill(ConsolePalette.divider)
            .frame(width: 1, height: 26)
            .padding(.horizontal, 12)
    }

    private func footerMetric(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(ConsolePalette.mutedText)
                Text(title)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(ConsolePalette.secondaryText)
            }
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(ConsolePalette.primaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            .padding(.vertical, 7)
            .background(ConsolePalette.panelRaised)
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }
}

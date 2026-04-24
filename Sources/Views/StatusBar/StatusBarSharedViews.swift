import SwiftUI

struct StatusPanelSection<Content: View>: View {
    let icon: String?
    let title: String
    let hint: String?
    @ViewBuilder let content: Content

    init(icon: String? = nil, title: String, hint: String? = nil, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.hint = hint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ConsolePalette.secondaryText)
                        .frame(width: 16)
                }

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ConsolePalette.primaryText)

                Spacer()

                if let hint, !hint.isEmpty {
                    Text(hint)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(ConsolePalette.secondaryText)
                }
            }

            content
        }
        .consolePanel()
    }
}

struct StatusTopologyMetric: View {
    let icon: String?
    let title: String
    let value: String
    let tint: Color

    init(icon: String? = nil, title: String, value: String, tint: Color = ConsolePalette.primaryText) {
        self.icon = icon
        self.title = title
        self.value = value
        self.tint = tint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(ConsolePalette.mutedText)
                }

                Text(title.uppercased())
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(ConsolePalette.secondaryText)
            }

            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(tint)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatusSubconsciousList: View {
    let rows: [SummaryRowData]

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if rows.isEmpty {
                Text("idle")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(ConsolePalette.mutedText)
            } else {
                HStack(spacing: 10) {
                    ForEach(rows, id: \.title) { row in
                        HStack(spacing: 4) {
                            Text(row.state == "WARM" ? "\u{2713}" : "\u{00B7}")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(row.tint)
                                .frame(width: 10)

                            Text(row.title)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(
                                    row.state == "WARM"
                                        ? ConsolePalette.secondaryText
                                        : ConsolePalette.primaryText
                                )
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .layoutPriority(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatusBadge: View {
    let title: String
    let tint: Color
    let showsIndicator: Bool

    init(title: String, tint: Color, showsIndicator: Bool = true) {
        self.title = title
        self.tint = tint
        self.showsIndicator = showsIndicator
    }

    var body: some View {
        HStack(spacing: 5) {
            if showsIndicator {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
            }
            Text(title)
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.10))
        .clipShape(Capsule())
    }
}

struct StatusHeroMetaBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.10))
            .clipShape(Capsule())
    }
}

struct StatusIconButton: View {
    let systemImage: String
    let tint: Color
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(tint.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

struct StatusSmallActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

struct StatusInlineConfigNotice: View {
    let message: String
    let tint: Color
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)

            Text(message)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(tint)

            Spacer()

            if let actionTitle, let action {
                StatusSmallActionButton(
                    title: actionTitle,
                    systemImage: "arrow.clockwise",
                    tint: tint,
                    isDisabled: false,
                    action: action
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }
}

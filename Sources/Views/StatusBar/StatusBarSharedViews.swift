import SwiftUI

/// A hairline panel with a mono header bar — the system's card pattern.
struct StatusPanelSection<Content: View>: View {
    let title: String
    let hint: String?
    @ViewBuilder let content: Content

    init(title: String, hint: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.hint = hint
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            ODPanelHeader(
                title: title,
                trailing: hint.map { hint in
                    AnyView(
                        Text(hint)
                            .font(.odMono(9))
                            .foregroundStyle(OpenDuo.textMuted)
                    )
                }
            )
            content
                .padding(12)
        }
        .odPanel()
    }
}

struct StatusTopologyMetric: View {
    let title: String
    let value: String
    let tint: Color

    init(title: String, value: String, tint: Color = OpenDuo.textPrimary) {
        self.title = title
        self.value = value
        self.tint = tint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ODKicker(text: title, tint: OpenDuo.textSecondary, size: 9)

            Text(value)
                .font(.odMono(11, weight: .medium))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .truncationMode(.tail)
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
                    .font(.odMono(10))
                    .foregroundStyle(OpenDuo.textMuted)
            } else {
                HStack(spacing: 10) {
                    ForEach(rows, id: \.title) { row in
                        HStack(spacing: 5) {
                            ODStateTick(tint: row.tint, size: 5)

                            Text(row.title)
                                .font(.odMono(10))
                                .foregroundStyle(
                                    row.state == "WARM"
                                        ? OpenDuo.textSecondary
                                        : OpenDuo.textPrimary
                                )
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .truncationMode(.middle)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A bare mono text label. No plate, no capsule — labels are bare mono type
/// on the surface.
struct StatusTextTag: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.odKicker(9))
            .foregroundStyle(tint)
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
        }
        .buttonStyle(ODIconButtonStyle(tint: tint))
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
            ODStateTick(tint: tint, size: 5)

            Text(message)
                .font(.odMono(10))
                .foregroundStyle(tint)

            Spacer()

            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9))
                        Text(actionTitle)
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .buttonStyle(ODOutlineButtonStyle(tint: tint))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .odInset()
    }
}

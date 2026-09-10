import SwiftUI

enum ConfigEditorMode {
    case panel
    case inline
}

// MARK: - Shared Config View Layout Helpers

extension View {
    /// Section header label used in config panels: a mono kicker.
    func configSectionLabel(_ title: String, mode _: ConfigEditorMode) -> some View {
        ODKicker(text: title, tint: OpenDuo.textSecondary)
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 4)
    }

    /// Divider with standard config panel horizontal inset
    func configRowDivider(mode _: ConfigEditorMode) -> some View {
        Rectangle()
            .fill(OpenDuo.borderHairline)
            .frame(height: 1)
            .padding(.horizontal, 14)
    }

    /// A labeled config row: label (with optional required indicator and env var hint) + content
    @ViewBuilder
    func configRow<Content: View>(
        mode _: ConfigEditorMode,
        label: String,
        required: Bool = false,
        hint: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(OpenDuo.textStrong)
                if required {
                    Text("*").foregroundStyle(OpenDuo.attention).font(.system(size: 11))
                }
                Spacer()
                Text(hint)
                    .font(.odMono(9))
                    .foregroundStyle(OpenDuo.textMuted)
            }
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    /// Square, hairline-framed config field. Invented to match Select metrics.
    func configTextField(text: Binding<String>, placeholder: String = "") -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.odMono(11))
            .foregroundStyle(OpenDuo.textStrong)
            .odField()
    }
}

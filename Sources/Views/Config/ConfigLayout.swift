import SwiftUI

enum ConfigEditorMode {
    case panel
    case inline
}

enum ConfigPalette {
    static func label(for mode: ConfigEditorMode) -> Color {
        mode == .inline ? ConsolePalette.primaryText : .primary
    }

    static func secondary(for mode: ConfigEditorMode) -> Color {
        mode == .inline ? ConsolePalette.secondaryText : .secondary
    }

    static func tertiary(for mode: ConfigEditorMode) -> Color {
        mode == .inline ? ConsolePalette.mutedText : .secondary.opacity(0.8)
    }

    static func divider(for mode: ConfigEditorMode) -> Color {
        mode == .inline ? ConsolePalette.divider : Color(nsColor: .separatorColor)
    }
}

// MARK: - Shared Config View Layout Helpers

extension View {
    /// Section header label used in config panels
    func configSectionLabel(_ title: String, mode: ConfigEditorMode) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(ConfigPalette.secondary(for: mode))
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 4)
    }

    /// Divider with standard config panel horizontal inset
    func configRowDivider(mode: ConfigEditorMode) -> some View {
        Divider()
            .overlay(ConfigPalette.divider(for: mode))
            .padding(.horizontal, 14)
    }

    /// A labeled config row: label (with optional required indicator and env var hint) + content
    @ViewBuilder
    func configRow<Content: View>(
        mode: ConfigEditorMode,
        label: String,
        required: Bool = false,
        hint: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ConfigPalette.label(for: mode))
                if required {
                    Text("*").foregroundStyle(.red).font(.system(size: 11))
                }
                Spacer()
                Text(hint)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(ConfigPalette.tertiary(for: mode))
            }
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }
}

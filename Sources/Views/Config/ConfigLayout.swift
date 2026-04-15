import SwiftUI

enum ConfigEditorMode {
    case panel
    case inline
}

// MARK: - Shared Config View Layout Helpers

extension View {
    /// Section header label used in config panels
    func configSectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 4)
    }

    /// Divider with standard config panel horizontal inset
    func configRowDivider() -> some View {
        Divider().padding(.horizontal, 14)
    }

    /// A labeled config row: label (with optional required indicator and env var hint) + content
    @ViewBuilder
    func configRow<Content: View>(
        label: String,
        required: Bool = false,
        hint: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                if required {
                    Text("*").foregroundStyle(.red).font(.system(size: 11))
                }
                Spacer()
                Text(hint)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.quaternary)
            }
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }
}

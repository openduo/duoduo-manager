import SwiftUI

struct SummaryRowData {
    let title: String
    let detail: String
    let state: String
    let tint: Color
}

enum ConsolePalette {
    static let background = Color(red: 0.028, green: 0.039, blue: 0.085)
    static let panel = Color(red: 0.045, green: 0.058, blue: 0.118)
    static let panelRaised = Color(red: 0.068, green: 0.084, blue: 0.156)
    static let divider = Color(red: 0.157, green: 0.212, blue: 0.341)

    static let primaryText = Color(red: 0.90, green: 0.94, blue: 1.00)
    static let secondaryText = Color(red: 0.56, green: 0.68, blue: 0.90)
    static let mutedText = Color(red: 0.38, green: 0.47, blue: 0.67)

    static let accent = Color(red: 0.22, green: 0.90, blue: 0.96)
    static let signal = Color(red: 0.38, green: 0.98, blue: 0.66)
    static let warning = Color(red: 1.00, green: 0.74, blue: 0.28)
    static let critical = Color(red: 1.00, green: 0.40, blue: 0.43)
    static let fuchsia = Color(red: 0.86, green: 0.48, blue: 1.00)
}

extension View {
    func consolePanel() -> some View {
        self
            .padding(12)
            .background(ConsolePalette.panel)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(ConsolePalette.divider, lineWidth: 1)
            )
    }

    func cardPanel() -> some View {
        self
            .background(ConsolePalette.panelRaised)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ConsolePalette.divider, lineWidth: 1)
            )
    }

    func measureStatusOverviewHeight() -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: StatusOverviewHeightPreferenceKey.self,
                    value: proxy.size.height
                )
            }
        )
    }
}

struct StatusOverviewHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

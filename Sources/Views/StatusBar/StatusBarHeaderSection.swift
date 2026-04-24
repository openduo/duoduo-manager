import SwiftUI

struct StatusHeaderBar: View {
    let runtimeLive: Bool
    let controlBusy: Bool
    let eventCount: Int
    let showAppUpdate: Bool
    let appVersion: String
    let isLoading: Bool
    let currentVersion: String
    let costValue: String
    let tokenValue: String
    let cacheValue: String
    let toolsValue: String
    let onAppUpdate: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            appGlyph

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("duoduo manager")
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ConsolePalette.primaryText)
                        .lineLimit(1)

                    if showAppUpdate {
                        Button(action: onAppUpdate) {
                            StatusBadge(title: L10n.Status.appUpdate(appVersion), tint: ConsolePalette.warning, showsIndicator: false)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("v\(currentVersion)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(ConsolePalette.secondaryText)
                    }

                }

                HStack(spacing: 10) {
                    headerMetric("cost", costValue, valueTint: Color(red: 0.82, green: 0.74, blue: 0.58))
                    headerMetric("tok", tokenValue, valueTint: Color(red: 0.61, green: 0.77, blue: 0.90))
                    headerMetric("cache", cacheValue, valueTint: Color(red: 0.59, green: 0.80, blue: 0.71))
                    headerMetric("tools", toolsValue, valueTint: Color(red: 0.73, green: 0.67, blue: 0.88))
                }
            }

            Spacer(minLength: 0)

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ConsolePalette.primaryText)
                    .frame(width: 30, height: 30)
                    .background(ConsolePalette.panelRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ConsolePalette.panel)
    }

    private var appGlyph: some View {
        Group {
            if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
               let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(ConsolePalette.divider, lineWidth: 1)
        )
    }

    private func headerMetric(_ title: String, _ value: String, valueTint: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundStyle(ConsolePalette.mutedText)
            Text(value)
                .foregroundStyle(valueTint)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .font(.system(size: 10, design: .monospaced))
    }
}

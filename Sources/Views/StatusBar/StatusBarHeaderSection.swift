import SwiftUI

struct StatusHeaderBar: View {
    let runtimeLive: Bool
    let controlBusy: Bool
    let eventCount: Int
    let showAppUpdate: Bool
    let appVersion: String
    let showRuntimeUpdate: Bool
    let isLoading: Bool
    let currentVersion: String
    let onAppUpdate: () -> Void
    let onRefresh: () -> Void
    let onUpgrade: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            appGlyph

            VStack(alignment: .leading, spacing: 7) {
                Text("duoduo manager")
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ConsolePalette.primaryText)

                HStack(spacing: 8) {
                    if showAppUpdate {
                        Button(action: onAppUpdate) {
                            StatusBadge(title: L10n.Status.appUpdate(appVersion), tint: ConsolePalette.warning)
                        }
                        .buttonStyle(.plain)
                    } else {
                        StatusBadge(title: "v\(currentVersion)", tint: ConsolePalette.accent)
                    }
                    StatusBadge(title: "events \(eventCount)", tint: ConsolePalette.accent)
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

            if showRuntimeUpdate {
                Button(action: onUpgrade) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ConsolePalette.warning)
                        .frame(width: 30, height: 30)
                        .background(ConsolePalette.panelRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(ConsolePalette.divider, lineWidth: 1)
        )
    }
}

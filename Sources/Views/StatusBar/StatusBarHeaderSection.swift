import SwiftUI

struct StatusHeaderBar: View {
    let runtimeLive: Bool
    let controlBusy: Bool
    let eventCount: Int
    let showAppUpdate: Bool
    let appVersion: String
    let showRuntimeUpdate: Bool
    let isLoading: Bool
    let onAppUpdate: () -> Void
    let onRuntimeAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            appGlyph

            VStack(alignment: .leading, spacing: 7) {
                Text("duoduo manager")
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ConsolePalette.primaryText)

                HStack(spacing: 8) {
                    StatusBadge(
                        title: runtimeLive ? "runtime live" : "runtime offline",
                        tint: runtimeLive ? ConsolePalette.signal : ConsolePalette.critical
                    )
                    StatusBadge(
                        title: controlBusy ? "control busy" : "control ready",
                        tint: controlBusy ? ConsolePalette.warning : ConsolePalette.secondaryText
                    )
                    StatusBadge(title: "events \(eventCount)", tint: ConsolePalette.accent)
                }
            }

            Spacer(minLength: 0)

            if showAppUpdate {
                Button(action: onAppUpdate) {
                    HStack(spacing: 8) {
                        Text("app \(appVersion)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(ConsolePalette.background)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ConsolePalette.warning)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onRuntimeAction) {
                    Image(systemName: showRuntimeUpdate ? "arrow.up.circle.fill" : "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(showRuntimeUpdate ? ConsolePalette.warning : ConsolePalette.primaryText)
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

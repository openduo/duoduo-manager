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

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("duoduo manager")

                    if showAppUpdate {
                        Button(action: onAppUpdate) {
                            Text(L10n.Status.appUpdate(appVersion))
                                .font(.odMono(10))
                                .foregroundStyle(OpenDuo.attention)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("v\(currentVersion)")
                            .font(.odMono(10))
                            .foregroundStyle(OpenDuo.textSecondary)
                    }
                }
                .font(.odDisplay(15))
                .foregroundStyle(OpenDuo.textStrong)

                HStack(spacing: 12) {
                    headerMetric("cost", costValue)
                    headerMetric("tok", tokenValue)
                    headerMetric("cache", cacheValue)
                    headerMetric("tools", toolsValue)
                }
            }

            Spacer(minLength: 0)

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(ODIconButtonStyle())
            .disabled(isLoading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(OpenDuo.surfacePanel)
        .overlay(alignment: .bottom) {
            Rectangle().fill(OpenDuo.borderHairline).frame(height: 1)
        }
    }

    /// The app icon, framed by a hairline. The icon asset carries its own
    /// rounded-square silhouette; the frame hugs it.
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
                .stroke(OpenDuo.borderSubtle, lineWidth: 1)
        )
    }

    private func headerMetric(_ title: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundStyle(OpenDuo.textMuted)
            Text(value)
                .foregroundStyle(OpenDuo.textPrimary)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .font(.odMono(10))
    }
}

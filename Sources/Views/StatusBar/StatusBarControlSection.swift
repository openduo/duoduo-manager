import SwiftUI

struct StatusServiceCard: View {
    let icon: String
    let name: String
    let version: String
    let hasUpdate: Bool
    let latestVersion: String
    let pid: String
    let isRunning: Bool
    let isLoading: Bool
    let runtimeHint: String?
    let runtimeHintTint: Color?
    let onConfig: (() -> Void)?
    let onStop: () -> Void
    let onRestart: () -> Void
    let onStart: () -> Void
    let expandedContent: AnyView?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ConsolePalette.secondaryText)
                    .frame(width: 32, height: 32)
                    .background(ConsolePalette.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ConsolePalette.divider, lineWidth: 1)
                    )

                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ConsolePalette.primaryText)

                Spacer(minLength: 0)

                if let onConfig {
                    StatusIconButton(
                        systemImage: "gearshape",
                        tint: ConsolePalette.secondaryText,
                        isDisabled: isLoading,
                        action: onConfig
                    )
                }

                if isRunning {
                    StatusIconButton(
                        systemImage: "stop.fill",
                        tint: ConsolePalette.critical,
                        isDisabled: isLoading,
                        action: onStop
                    )
                    StatusIconButton(
                        systemImage: "arrow.clockwise",
                        tint: ConsolePalette.warning,
                        isDisabled: isLoading,
                        action: onRestart
                    )
                } else {
                    StatusIconButton(
                        systemImage: "play.fill",
                        tint: ConsolePalette.signal,
                        isDisabled: isLoading,
                        action: onStart
                    )
                }
            }

            HStack(spacing: 0) {
                if !version.isEmpty {
                    Text("v\(version)")
                        .foregroundStyle(hasUpdate ? ConsolePalette.warning : ConsolePalette.secondaryText)

                    if hasUpdate && !latestVersion.isEmpty {
                        Text(" → v\(latestVersion)")
                            .foregroundStyle(ConsolePalette.warning)
                    }

                    if !pid.isEmpty {
                        Text(" · ")
                            .foregroundStyle(ConsolePalette.mutedText)
                    }
                }

                if !pid.isEmpty {
                    Text("PID \(pid)")
                        .foregroundStyle(ConsolePalette.secondaryText)
                }

                Spacer()

                Circle()
                    .fill(isRunning ? ConsolePalette.signal : ConsolePalette.mutedText)
                    .frame(width: 6, height: 6)

                Text(isRunning ? L10n.Status.running : L10n.Status.stopped)
                    .padding(.leading, 6)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isRunning ? ConsolePalette.signal : ConsolePalette.secondaryText)

                if let runtimeHint, !runtimeHint.isEmpty {
                    Text(" · ")
                        .foregroundStyle(ConsolePalette.mutedText)

                    Text(runtimeHint)
                        .foregroundStyle(runtimeHintTint ?? ConsolePalette.warning)
                }
            }
            .font(.system(size: 10, design: .monospaced))

            if let expandedContent {
                Divider().overlay(ConsolePalette.divider)
                expandedContent
            }
        }
        .padding(12)
        .cardPanel()
    }
}

struct StatusInstallCard: View {
    let iconName: String
    let name: String
    let packageName: String
    let isLoading: Bool
    let runtimeHint: String?
    let runtimeHintTint: Color?
    let onConfig: (() -> Void)?
    let onInstall: () -> Void
    let expandedContent: AnyView?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ConsolePalette.secondaryText)
                    .frame(width: 32, height: 32)
                    .background(ConsolePalette.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ConsolePalette.divider, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ConsolePalette.primaryText)

                    Text(packageName)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(ConsolePalette.secondaryText)
                }

                Spacer()

                if let onConfig {
                    StatusIconButton(
                        systemImage: "gearshape",
                        tint: ConsolePalette.secondaryText,
                        isDisabled: isLoading,
                        action: onConfig
                    )
                }

                StatusSmallActionButton(
                    title: "install",
                    systemImage: "arrow.down.circle.fill",
                    tint: ConsolePalette.accent,
                    isDisabled: isLoading,
                    action: onInstall
                )
            }

            if let runtimeHint, !runtimeHint.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(runtimeHintTint ?? ConsolePalette.warning)

                    Text(runtimeHint)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(runtimeHintTint ?? ConsolePalette.warning)

                    Spacer()
                }
            }

            if let expandedContent {
                Divider().overlay(ConsolePalette.divider)
                expandedContent
            }
        }
        .padding(12)
        .cardPanel()
    }
}

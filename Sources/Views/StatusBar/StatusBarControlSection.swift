import SwiftUI

private enum StatusCardLayout {
    static let iconButton: CGFloat = 22
    static let actionGap: CGFloat = 10
    /// Matches two icon buttons with the row gap, so Install/Start lines up with Stop+Restart.
    static let pairActionsWidth: CGFloat = iconButton * 2 + actionGap
}

struct StatusOperationsMenu: View {
    let title: String
    let installSkillsTitle: String
    let autostartTitle: String
    let autostartEnabled: Bool
    let isDisabled: Bool
    let onInstallSkills: () -> Void
    let onToggleAutostart: () -> Void

    var body: some View {
        Menu {
            Button(action: onInstallSkills) {
                Label(installSkillsTitle, systemImage: "sparkles")
            }
            Button(action: onToggleAutostart) {
                Label(autostartTitle, systemImage: autostartEnabled ? "poweroff" : "power")
            }
        } label: {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(ODOutlineButtonStyle(tint: OpenDuo.textAccentSoft))
        .fixedSize(horizontal: true, vertical: false)
        .disabled(isDisabled)
    }
}

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
    /// Whether this card's start button is the scene's cyan primary. Only
    /// the daemon start earns the fill; channel starts are outline actions,
    /// so a stopped daemon + stopped channel never shows two cyan fills.
    /// An expanded inline config also stands the start button down — its
    /// Save button is the primary while editing.
    var isPrimaryStartAction: Bool = true
    let expandedContent: AnyView?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(OpenDuo.textSecondary)
                    .frame(width: 30, height: 30)
                    .odInset()

                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OpenDuo.textStrong)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let onConfig {
                    StatusIconButton(
                        systemImage: "gearshape",
                        tint: OpenDuo.textSecondary,
                        isDisabled: isLoading,
                        action: onConfig
                    )
                }

                if isRunning {
                    StatusIconButton(
                        systemImage: "stop.fill",
                        tint: OpenDuo.textSecondary,
                        isDisabled: isLoading,
                        action: onStop
                    )
                    StatusIconButton(
                        systemImage: "arrow.clockwise",
                        tint: OpenDuo.textSecondary,
                        isDisabled: isLoading,
                        action: onRestart
                    )
                } else if isPrimaryStartAction && expandedContent == nil {
                    Button(action: onStart) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .buttonStyle(ODPrimaryButtonStyle(compact: true))
                    .frame(width: StatusCardLayout.pairActionsWidth, height: StatusCardLayout.iconButton)
                    .disabled(isLoading)
                } else {
                    Button(action: onStart) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(ODOutlineButtonStyle(tint: OpenDuo.ok))
                    .frame(width: StatusCardLayout.pairActionsWidth, height: StatusCardLayout.iconButton)
                    .disabled(isLoading)
                }
            }
            .padding(10)

            metaLine
                .padding(.horizontal, 10)
                .padding(.bottom, 10)

            if let expandedContent {
                odHRule()
                expandedContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .odPanel(surface: OpenDuo.surfaceInset, border: OpenDuo.borderSubtle)
    }

    private var metaLine: some View {
        HStack(spacing: 0) {
            if !version.isEmpty {
                Text("v\(version)")
                    .foregroundStyle(hasUpdate ? OpenDuo.attention : OpenDuo.textSecondary)

                if hasUpdate && !latestVersion.isEmpty {
                    Text(" → v\(latestVersion)")
                        .foregroundStyle(OpenDuo.attention)
                }

                if !pid.isEmpty {
                    Text(" · ")
                        .foregroundStyle(OpenDuo.textMuted)
                }
            }

            if !pid.isEmpty {
                Text("PID \(pid)")
                    .foregroundStyle(OpenDuo.textSecondary)
            }

            Spacer()

            ODSignalDot(tint: OpenDuo.ok, isLive: isRunning)

            Text(isRunning ? L10n.Status.running : L10n.Status.stopped)
                .padding(.leading, 6)
                .foregroundStyle(isRunning ? OpenDuo.ok : OpenDuo.textSecondary)

            if let runtimeHint, !runtimeHint.isEmpty {
                Text(" · ")
                    .foregroundStyle(OpenDuo.textMuted)

                Text(runtimeHint)
                    .foregroundStyle(runtimeHintTint ?? OpenDuo.attention)
            }
        }
        .font(.odMono(10))
    }
}

struct StatusInstallCard: View {
    let iconName: String
    let name: String
    let packageName: String
    let isLoading: Bool
    var isBusy: Bool = false
    var actionTitle: String = L10n.Status.install
    let runtimeHint: String?
    let runtimeHintTint: Color?
    let onConfig: (() -> Void)?
    let onInstall: () -> Void
    let expandedContent: AnyView?

    init(
        presentation: StatusInstallCardPresentation,
        runtimeHint: String? = nil,
        runtimeHintTint: Color? = nil,
        onConfig: (() -> Void)? = nil,
        onInstall: @escaping () -> Void,
        expandedContent: AnyView? = nil
    ) {
        iconName = presentation.iconName
        name = presentation.name
        packageName = presentation.packageName
        isLoading = presentation.isLoading
        isBusy = presentation.isBusy
        actionTitle = presentation.actionTitle
        self.runtimeHint = runtimeHint
        self.runtimeHintTint = runtimeHintTint
        self.onConfig = onConfig
        self.onInstall = onInstall
        self.expandedContent = expandedContent
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(OpenDuo.textSecondary)
                    .frame(width: 30, height: 30)
                    .odInset()

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OpenDuo.textStrong)

                    Text(packageName)
                        .font(.odMono(10))
                        .foregroundStyle(OpenDuo.textSecondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let onConfig {
                    StatusIconButton(
                        systemImage: "gearshape",
                        tint: OpenDuo.textSecondary,
                        isDisabled: isLoading,
                        action: onConfig
                    )
                }

                Button(action: onInstall) {
                    HStack(spacing: 3) {
                        if isBusy {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(OpenDuo.ok)
                        } else {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        Text(actionTitle)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(ODOutlineButtonStyle(tint: OpenDuo.ok))
                .frame(width: StatusCardLayout.pairActionsWidth, height: StatusCardLayout.iconButton)
                .disabled(isLoading)
            }
            .padding(10)

            if let runtimeHint, !runtimeHint.isEmpty {
                HStack(spacing: 6) {
                    Text(runtimeHint)
                        .font(.odMono(10))
                        .foregroundStyle(runtimeHintTint ?? OpenDuo.attention)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }

            if let expandedContent {
                odHRule()
                expandedContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .odPanel(surface: OpenDuo.surfaceInset, border: OpenDuo.borderSubtle)
    }
}

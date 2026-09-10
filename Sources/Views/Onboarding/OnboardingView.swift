import AppKit
import SwiftUI

private struct OnboardingContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 440

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct OnboardingView: View {
    @Bindable var store: OnboardingStore
    let onClose: () -> Void
    var onPreferredHeightChange: (CGFloat) -> Void = { _ in }
    @State private var shellPathStatus: ShellPathInstaller.Status = .installed
    @State private var shellPathErrorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(OpenDuo.borderHairline).frame(height: 1)
            Group {
                if store.state.step == .complete {
                    completionView
                } else {
                    taskList
                }
            }
        }
        .background(OpenDuo.page)
        .odChrome()
        .frame(width: 620)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: OnboardingContentHeightKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(OnboardingContentHeightKey.self) { height in
            onPreferredHeightChange(height)
        }
        .animation(.easeInOut(duration: 0.15), value: store.state.step)
        .animation(.easeInOut(duration: 0.15), value: store.state.currentRequirement)
        .task {
            if store.state.step == .detecting,
               store.state.currentRequirement == nil,
               store.state.statusMessage == nil {
                store.send(.bootstrap)
            }
        }
        .task(id: autoAdvanceKey) {
            autoAdvanceIfNeeded()
        }
        .task(id: store.state.step == .complete) {
            guard store.state.step == .complete else {
                shellPathStatus = .installed
                shellPathErrorMessage = nil
                return
            }
            await prepareCompletionSupplementaryPanel()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            ODKicker(text: L10n.Onboard.headerTitle, tint: OpenDuo.textKicker)

            Spacer()

            Text(progressCounter)
                .font(.odMono(12))
                .foregroundStyle(OpenDuo.textSecondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var taskList: some View {
        VStack(spacing: 0) {
            ForEach(Array(OnboardingRequirement.allCases.enumerated()), id: \.element.id) { index, requirement in
                TaskRow(
                    requirement: requirement,
                    phase: phase(for: requirement),
                    statusText: statusText(for: requirement),
                    isExpanded: requirement == expandedRequirement,
                    isBusy: store.state.isBusy && requirement == store.state.currentRequirement,
                    isFirst: index == 0,
                    isLast: index == OnboardingRequirement.allCases.count - 1,
                    store: store,
                    onClose: onClose
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var completionView: some View {
        completionWideLayout
            .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 34)
        .padding(.vertical, 28)
    }

    private var completionWideLayout: some View {
        HStack(alignment: .top, spacing: 30) {
            completionHeroColumn

            completionAxis

            completionInfoColumn
        }
    }

    private var expandedRequirement: OnboardingRequirement? {
        switch store.state.step {
        case .complete:
            return .daemon
        case .detecting:
            return store.state.currentRequirement ?? OnboardingRequirement.allCases.first
        case .ready:
            return store.state.currentRequirement
        }
    }

    private func phase(for requirement: OnboardingRequirement) -> TaskRow.Phase {
        switch store.state.step {
        case .complete:
            return .complete
        case .detecting:
            if requirement == expandedRequirement {
                return .current
            }
            return .upcoming
        case .ready:
            if requirement == store.state.currentRequirement { return .current }
            if isComplete(requirement) { return .complete }
            return .upcoming
        }
    }

    private func isComplete(_ requirement: OnboardingRequirement) -> Bool {
        !store.state.snapshot.unmetRequirements.contains(requirement)
    }

    private func statusText(for requirement: OnboardingRequirement) -> String {
        switch phase(for: requirement) {
        case .complete:
            switch requirement {
            case .duoduoCLI:
                return installedLabel(store.state.snapshot.duoduoVersion)
            case .claudeAccess:
                return L10n.Onboard.connected
            case .daemon:
                return daemonCompletionLabel
            }
        case .current:
            if requirement == store.state.currentRequirement, let error = store.state.errorMessage {
                return error
            }
            if store.state.step == .detecting {
                return L10n.Onboard.detecting
            }
            switch requirement {
            case .duoduoCLI:
                return L10n.Onboard.installing
            case .claudeAccess:
                return L10n.Onboard.needToken
            case .daemon:
                return L10n.Onboard.starting
            }
        case .upcoming:
            return L10n.Onboard.waiting
        }
    }

    private var progressCounter: String {
        let done = OnboardingRequirement.allCases.filter(isComplete).count
        return "[\(done)/\(OnboardingRequirement.allCases.count)]"
    }

    private func installedLabel(_ version: String?) -> String {
        guard let version, !version.isEmpty else { return "v --" }
        let trimmed = version.components(separatedBy: " (").first ?? version
        return "v\(trimmed)"
    }

    private var daemonCompletionLabel: String {
        if let pid = store.state.snapshot.daemonPID, !pid.isEmpty {
            return "PID \(pid)"
        }
        return "PID --"
    }

    private var completionHeroColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            ODKicker(text: L10n.Onboard.setupComplete, tint: OpenDuo.textKickerNeutral)

            ODHeadline(text: L10n.Onboard.enjoy, size: 48)

            if showsCompletionSupplementaryPanel {
                AgentShellPathPanel(
                    duoduoVersion: store.state.snapshot.duoduoVersion,
                    errorMessage: $shellPathErrorMessage
                )
                    .padding(.top, 2)
            } else {
                Text(L10n.Onboard.readyHint)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(OpenDuo.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
        .frame(width: 236, alignment: .leading)
    }

    private var showsCompletionSupplementaryPanel: Bool {
        NodeRuntime.hasBundledNode && (shellPathGateMessage != nil || shellPathStatus != .installed || shellPathErrorMessage != nil)
    }

    private var shellPathGateMessage: String? {
        guard store.state.snapshot.duoduoVersion != nil else {
            return L10n.Onboard.ShellPath.gateRequiresInstall
        }
        if !DuoduoCompat.meetsMinimum(
            installed: store.state.snapshot.duoduoVersion,
            minimum: DuoduoCompat.minVersionForNodeBinEnv
        ) {
            return L10n.Onboard.ShellPath.gateRequiresUpgrade(DuoduoCompat.minVersionForNodeBinEnv)
        }
        return nil
    }

    private func prepareCompletionSupplementaryPanel() async {
        guard NodeRuntime.hasBundledNode else {
            shellPathStatus = .installed
            shellPathErrorMessage = nil
            return
        }

        let detectedStatus = ShellPathInstaller.detect()
        shellPathStatus = detectedStatus

        guard shellPathGateMessage == nil else {
            shellPathErrorMessage = nil
            return
        }

        guard detectedStatus != .installed else {
            shellPathErrorMessage = nil
            return
        }

        do {
            let newStatus = try await Task.detached(priority: .userInitiated) {
                try ShellPathInstaller.install()
                return ShellPathInstaller.detect()
            }.value
            shellPathStatus = newStatus
            shellPathErrorMessage = newStatus == .installed ? nil : L10n.Onboard.ShellPath.autoRepairFailed
        } catch {
            shellPathErrorMessage = error.localizedDescription
        }
    }

    /// A static hairline axis with the live signal dot at its foot. The one
    /// element allowed a glow.
    private var completionAxis: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(OpenDuo.borderSubtle)
                .frame(width: 1)

            ODSignalDot()
                .padding(.top, 6)
        }
        .frame(width: 12, alignment: .top)
        .frame(maxHeight: 230, alignment: .top)
    }

    private var completionInfoColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 0) {
                completionMetricRow("Duoduo", installedLabel(store.state.snapshot.duoduoVersion))
                completionMetricRow("Claude SDK", L10n.Onboard.connected)
                completionMetricRow(L10n.Onboard.metricModel, L10n.Onboard.connected)
                completionMetricRow("Daemon", daemonCompletionLabel, showsDivider: false)
            }

            HStack(spacing: 10) {
                Button {
                    store.send(.editRequirementRequested(.claudeAccess))
                } label: {
                    Text(L10n.Onboard.editConfig)
                }
                .buttonStyle(ODOutlineButtonStyle())

                Button(action: onClose) {
                    Text(L10n.Onboard.close)
                }
                .buttonStyle(ODQuietButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    private func completionMetricRow(_ title: String, _ value: String, showsDivider: Bool = true) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(OpenDuo.textMuted)

                Text(value)
                    .font(.odMono(12, weight: .medium))
                    .foregroundStyle(OpenDuo.textPrimary)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsDivider {
                Rectangle().fill(OpenDuo.borderHairline).frame(height: 1)
            }
        }
    }

    private var autoAdvanceKey: String {
        [
            store.state.step == .ready ? "ready" : "other",
            store.state.currentRequirement?.rawValue ?? "none",
            store.state.isBusy ? "busy" : "idle"
        ].joined(separator: ":")
    }

    private func autoAdvanceIfNeeded() {
        guard store.state.step == .ready, !store.state.isBusy else { return }
        guard store.state.errorMessage == nil else { return }
        switch store.state.currentRequirement {
        case .duoduoCLI:
            store.send(.installDuoduoRequested)
        default:
            break
        }
    }
}

private struct TaskRow: View {
    enum Phase {
        case complete
        case current
        case upcoming
    }

    let requirement: OnboardingRequirement
    let phase: Phase
    let statusText: String
    let isExpanded: Bool
    let isBusy: Bool
    let isFirst: Bool
    let isLast: Bool
    @Bindable var store: OnboardingStore
    let onClose: () -> Void
    @FocusState private var tokenFieldFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            leadingRail
            rowBody
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private var leadingRail: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(OpenDuo.borderSubtle)
                .frame(width: 1, height: 18)
                .opacity(isFirst ? 0 : 1)

            HStack(spacing: 0) {
                Rectangle()
                    .fill(OpenDuo.borderSubtle)
                    .frame(width: 16, height: 1)

                checkbox
            }
            .frame(height: 26)

            Rectangle()
                .fill(OpenDuo.borderSubtle)
                .frame(width: 1, height: connectorHeight)
                .opacity(isLast ? 0 : 1)
        }
        .frame(width: 72, alignment: .leading)
        .padding(.top, 2)
    }

    /// Square checkbox — the only shape a marker is allowed to be.
    private var checkbox: some View {
        ZStack {
            Rectangle()
                .stroke(borderTint, lineWidth: 1.4)
                .frame(width: 17, height: 17)

            if phase == .complete {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(OpenDuo.ok)
            }
        }
    }

    private var rowBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(requirement.title)
                .font(.odDisplay(16))
                .foregroundStyle(titleTint)

            Text(statusText)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(detailTint)

            if isExpanded {
                expandedBody
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 0)
        .padding(.bottom, isExpanded ? 8 : 20)
        .contentTransition(.opacity)
    }

    @ViewBuilder
    private var expandedBody: some View {
        switch phase {
        case .complete:
            EmptyView()

        case .current:
            switch requirement {
            case .claudeAccess:
                tokenSetup
            case .daemon:
                daemonSetup
            default:
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .tint(OpenDuo.brand)
                        .padding(.top, 10)
                        .frame(maxWidth: 320, alignment: .leading)
                }
            }

        case .upcoming:
            EmptyView()
        }
    }

    private var tokenSetup: some View {
        VStack(alignment: .leading, spacing: 12) {
            providerMenu

            if store.state.selectedPreset == .official {
                officialLoginUI
            } else {
                tokenField

                if store.state.selectedPreset == .custom {
                    simpleField(
                        placeholder: L10n.Onboard.baseUrlPlaceholder,
                        text: Binding(
                            get: { store.state.customBaseURL },
                            set: { store.send(.customBaseURLChanged($0)) }
                        )
                    )

                    simpleField(
                        placeholder: L10n.Onboard.modelPlaceholder,
                        text: Binding(
                            get: { store.state.customModel },
                            set: { store.send(.customModelChanged($0)) }
                        )
                    )
                }

                HStack(spacing: 10) {
                    Button {
                        store.send(.saveProviderRequested)
                    } label: {
                        Text(store.state.isBusy ? L10n.Onboard.saving : L10n.Onboard.continue_)
                    }
                    .buttonStyle(ODPrimaryButtonStyle())
                    .disabled(store.state.isBusy || !store.state.canSaveProvider)

                    Button {
                        store.send(.verifyClaudeStatusRequested)
                    } label: {
                        Text(L10n.Onboard.verify)
                    }
                    .buttonStyle(ODOutlineButtonStyle())
                }
            }

            if let message = store.state.errorMessage ?? store.state.statusMessage {
                Text(message)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(store.state.errorMessage == nil ? OpenDuo.textSecondary : OpenDuo.alert)
                    .padding(.top, 2)
            }
        }
        .padding(.top, 10)
        .frame(maxWidth: 320, alignment: .leading)
    }

    private var daemonSetup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Onboard.workDirPrompt)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(OpenDuo.textSecondary)

            HStack(spacing: 8) {
                simpleField(
                    placeholder: DaemonConfig.defaultWorkDir,
                    text: Binding(
                        get: { store.state.daemonWorkDir },
                        set: { store.send(.daemonWorkDirChanged($0)) }
                    )
                )

                Button {
                    selectWorkDir()
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 12, weight: .regular))
                }
                .buttonStyle(ODIconButtonStyle(tint: OpenDuo.textSecondary))
                .disabled(store.state.isBusy)
            }

            Button {
                store.send(.startDaemonRequested)
            } label: {
                Text(store.state.isBusy ? L10n.Onboard.starting : L10n.Onboard.startDaemon)
            }
            .buttonStyle(ODPrimaryButtonStyle())
            .disabled(store.state.isBusy)

            if let message = store.state.errorMessage ?? store.state.statusMessage {
                Text(message)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(store.state.errorMessage == nil ? OpenDuo.textSecondary : OpenDuo.alert)
                    .padding(.top, 2)
            }
        }
        .padding(.top, 10)
        .frame(maxWidth: 360, alignment: .leading)
    }

    private func selectWorkDir() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = L10n.DaemonConfig.workDirPanelMessage
        panel.directoryURL = URL(fileURLWithPath: store.state.daemonWorkDir, isDirectory: true)
        if panel.runModal() == .OK, let url = panel.url {
            store.send(.daemonWorkDirChanged(url.path))
        }
    }

    private var providerMenu: some View {
        Menu {
            ForEach(LLMProviderPreset.allPresets()) { preset in
                Button {
                    store.send(.providerPresetChanged(preset))
                } label: {
                    HStack {
                        Text(preset.name)
                        if store.state.selectedPreset == preset {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: store.state.selectedPreset.icon)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(OpenDuo.textMuted)

                Text(store.state.selectedPreset.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OpenDuo.textPrimary)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(OpenDuo.textMuted)
            }
            .odField(horizontal: 10, vertical: 8)
        }
        .buttonStyle(.plain)
    }

    private var officialLoginUI: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Onboard.officialHint)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(OpenDuo.textSecondary)

            Button {
                store.send(.oauthLoginRequested)
            } label: {
                Text(store.state.isBusy ? L10n.Onboard.waitingLogin : L10n.Onboard.browserLogin)
            }
            .buttonStyle(ODPrimaryButtonStyle())
            .disabled(store.state.isBusy)
        }
    }

    private var tokenField: some View {
        HStack(spacing: 8) {
            Group {
                if store.state.showSecret {
                    TextField(L10n.Onboard.tokenPlaceholder, text: Binding(
                        get: { store.state.authToken },
                        set: { store.send(.authTokenChanged($0)) }
                    ))
                } else {
                    SecureField(L10n.Onboard.tokenPlaceholder, text: Binding(
                        get: { store.state.authToken },
                        set: { store.send(.authTokenChanged($0)) }
                    ))
                }
            }
            .focused($tokenFieldFocused)
            .textFieldStyle(.plain)
            .font(.odMono(12))
            .foregroundStyle(OpenDuo.textPrimary)
            .odField(horizontal: 10, vertical: 8)

            Button {
                store.send(.showSecretToggled)
            } label: {
                Image(systemName: store.state.showSecret ? "eye.slash" : "eye")
                    .font(.system(size: 11, weight: .regular))
            }
            .buttonStyle(ODIconButtonStyle())
        }
        .onAppear {
            DispatchQueue.main.async {
                tokenFieldFocused = true
            }
        }
    }

    private func simpleField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.odMono(12))
            .foregroundStyle(OpenDuo.textPrimary)
            .odField(horizontal: 10, vertical: 8)
    }

    private var titleTint: Color {
        switch phase {
        case .complete:
            return OpenDuo.textStrong
        case .current:
            return OpenDuo.textStrong
        case .upcoming:
            return OpenDuo.textFaint
        }
    }

    private var detailTint: Color {
        phase == .upcoming ? OpenDuo.textFaint : OpenDuo.textSecondary
    }

    private var borderTint: Color {
        switch phase {
        case .complete:
            return OpenDuo.ok
        case .current:
            return OpenDuo.brand
        case .upcoming:
            return OpenDuo.borderStrong
        }
    }

    private var connectorHeight: CGFloat {
        if isExpanded {
            if requirement == .claudeAccess { return 148 }
            if requirement == .daemon { return 142 }
            return 72
        }
        return 52
    }
}

/// Post-completion enhancement: lets the user opt into having
/// `~/.duoduo-manager/bin` on their interactive shell PATH so agent
/// subprocesses can resolve `duoduo`. Gated on the installed duoduo
/// version actually honoring `DUODUO_NODE_BIN`.
private struct AgentShellPathPanel: View {
    let duoduoVersion: String?
    @Binding var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                ODKicker(text: L10n.Onboard.ShellPath.title, tint: OpenDuo.textSecondary)

                Spacer()

                statusControl
            }

            Text(summaryText)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(OpenDuo.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let gateMessage {
                Text(gateMessage)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(OpenDuo.attention)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(OpenDuo.alert)
            }
        }
        .padding(12)
        .odPanel(surface: OpenDuo.surfaceInset, border: OpenDuo.borderSubtle)
    }

    private var gateMessage: String? {
        guard duoduoVersion != nil else {
            return L10n.Onboard.ShellPath.gateRequiresInstall
        }
        if !DuoduoCompat.meetsMinimum(installed: duoduoVersion, minimum: DuoduoCompat.minVersionForNodeBinEnv) {
            return L10n.Onboard.ShellPath.gateRequiresUpgrade(DuoduoCompat.minVersionForNodeBinEnv)
        }
        return nil
    }

    /// Bare mono type on the surface — labels are never plated.
    @ViewBuilder
    private var statusControl: some View {
        ODKicker(text: L10n.Onboard.ShellPath.stateNeedsManualAction, tint: OpenDuo.attention)
    }

    private var summaryText: String {
        errorMessage == nil ? L10n.Onboard.ShellPath.summary : L10n.Onboard.ShellPath.summaryFailed
    }
}

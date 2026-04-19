import SwiftUI

struct OnboardingView: View {
    @Bindable var store: OnboardingStore
    let onClose: () -> Void
    @State private var completionReveal = false
    @State private var completionAxisShift = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(ConsolePalette.divider)
            if store.state.step == .complete {
                completionView
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                taskList
                    .transition(.opacity)
            }
        }
        .background(ConsolePalette.background)
        .animation(.easeOut(duration: 0.22), value: store.state.step)
        .animation(.easeOut(duration: 0.22), value: store.state.currentRequirement)
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
                completionReveal = false
                completionAxisShift = false
                return
            }
            withAnimation(.easeOut(duration: 0.35)) {
                completionReveal = true
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                completionAxisShift = true
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ConsolePalette.secondaryText)
                    .frame(width: 18)

                Text(L10n.Onboard.headerTitle)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(ConsolePalette.primaryText)
            }

            Spacer()

            Text(progressCounter)
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .foregroundStyle(ConsolePalette.secondaryText)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
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
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            HStack(alignment: .top, spacing: 34) {
                completionHeroColumn
                    .offset(y: completionReveal ? 0 : 10)
                    .opacity(completionReveal ? 1 : 0)

                completionAxis
                    .offset(y: completionReveal ? 0 : 18)
                    .opacity(completionReveal ? 1 : 0)

                completionInfoColumn
                    .offset(y: completionReveal ? 0 : 14)
                    .opacity(completionReveal ? 1 : 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 34)
        .padding(.vertical, 34)
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
            case .claudeCLI:
                return installedLabel(store.state.snapshot.claudeVersion)
            case .claudeAccess:
                return L10n.Onboard.connected
            case .daemon:
                return daemonCompletionLabel
            }
        case .current:
            if store.state.step == .detecting {
                return L10n.Onboard.detecting
            }
            switch requirement {
            case .duoduoCLI:
                return L10n.Onboard.installing
            case .claudeCLI:
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
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.Onboard.setupComplete)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(ConsolePalette.secondaryText)

            Text("Enjoy.")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(ConsolePalette.primaryText)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [ConsolePalette.accent, ConsolePalette.secondaryText],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 108, height: 3)
                .clipShape(Capsule())

            Text(L10n.Onboard.readyHint)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ConsolePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 214, alignment: .leading)
    }

    private var completionAxis: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(ConsolePalette.divider.opacity(0.7))
                .frame(width: 1)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [ConsolePalette.accent.opacity(0.2), ConsolePalette.accent, ConsolePalette.signal.opacity(0.24)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3, height: 72)
                .offset(y: completionAxisShift ? 138 : 8)
        }
        .frame(width: 12, height: 230)
    }

    private var completionInfoColumn: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(spacing: 0) {
                completionMetricRow("Duoduo", installedLabel(store.state.snapshot.duoduoVersion))
                completionMetricRow("Claude SDK", installedLabel(store.state.snapshot.claudeVersion))
                completionMetricRow(L10n.Onboard.metricModel, L10n.Onboard.connected)
                completionMetricRow("Daemon", daemonCompletionLabel, showsDivider: false)
            }

            AgentShellPathPanel(duoduoVersion: store.state.snapshot.duoduoVersion)

            HStack(spacing: 12) {
                primaryButton(title: L10n.Onboard.editConfig, tint: ConsolePalette.accent, disabled: false) {
                    store.send(.editRequirementRequested(.claudeAccess))
                }

                Button(action: onClose) {
                    Text(L10n.Onboard.close)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ConsolePalette.secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 16)
    }

    private func completionMetricRow(_ title: String, _ value: String, showsDivider: Bool = true) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ConsolePalette.mutedText)

                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ConsolePalette.primaryText)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsDivider {
                Divider().overlay(ConsolePalette.divider.opacity(0.7))
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
        switch store.state.currentRequirement {
        case .duoduoCLI:
            store.send(.installDuoduoRequested)
        case .claudeCLI:
            store.send(.installClaudeRequested)
        case .daemon:
            store.send(.startDaemonRequested)
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
                .fill(ConsolePalette.divider.opacity(0.8))
                .frame(width: 2, height: 18)
                .opacity(isFirst ? 0 : 1)

            HStack(spacing: 0) {
                Rectangle()
                    .fill(ConsolePalette.divider.opacity(0.8))
                    .frame(width: 18, height: 2)

                checkbox
            }
            .frame(height: 26)

            Rectangle()
                .fill(ConsolePalette.divider.opacity(0.8))
                .frame(width: 2, height: connectorHeight)
                .opacity(isLast ? 0 : 1)
        }
        .frame(width: 72, alignment: .leading)
        .padding(.top, 2)
    }

    private var checkbox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(phase == .complete ? ConsolePalette.signal.opacity(0.12) : .clear)
                .frame(width: 18, height: 18)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(borderTint, lineWidth: 1.6)
                )

            if phase == .complete {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ConsolePalette.signal)
            }
        }
    }

    private var rowBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(requirement.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(titleTint)

            Text(statusText)
                .font(.system(size: 12, weight: .medium))
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
            default:
                ProgressView(value: 0.66)
                    .tint(highlightTint)
                    .padding(.top, 10)
                    .frame(maxWidth: 320)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .leading)))
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
                    primaryButton(
                        title: store.state.isBusy ? L10n.Onboard.saving : L10n.Onboard.continue_,
                        tint: ConsolePalette.accent,
                        disabled: store.state.isBusy || !store.state.canSaveProvider
                    ) {
                        store.send(.saveProviderRequested)
                    }

                    secondaryButton(title: L10n.Onboard.verify) {
                        store.send(.verifyClaudeStatusRequested)
                    }
                }
            }

            if let message = store.state.errorMessage ?? store.state.statusMessage {
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(store.state.errorMessage == nil ? ConsolePalette.secondaryText : ConsolePalette.critical)
                    .padding(.top, 2)
            }
        }
        .padding(.top, 10)
        .frame(maxWidth: 320, alignment: .leading)
        .transition(.opacity.combined(with: .move(edge: .top)))
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
            HStack(spacing: 10) {
                Image(systemName: store.state.selectedPreset.icon)
                    .font(.system(size: 11, weight: .semibold))

                Text(store.state.selectedPreset.name)
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(ConsolePalette.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(ConsolePalette.panelRaised)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(ConsolePalette.divider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var officialLoginUI: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Onboard.officialHint)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ConsolePalette.secondaryText)

            primaryButton(
                title: store.state.isBusy ? L10n.Onboard.waitingLogin : L10n.Onboard.browserLogin,
                tint: ConsolePalette.accent,
                disabled: store.state.isBusy
            ) {
                store.send(.oauthLoginRequested)
            }
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
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(ConsolePalette.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(ConsolePalette.panelRaised)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(ConsolePalette.divider, lineWidth: 1)
            )

            Button {
                store.send(.showSecretToggled)
            } label: {
                Image(systemName: store.state.showSecret ? "eye.slash" : "eye")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ConsolePalette.secondaryText)
                    .frame(width: 36, height: 36)
                    .background(ConsolePalette.panelRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(ConsolePalette.divider, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
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
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(ConsolePalette.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(ConsolePalette.panelRaised)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(ConsolePalette.divider, lineWidth: 1)
            )
    }

    private var titleTint: Color {
        switch phase {
        case .complete:
            return ConsolePalette.primaryText
        case .current:
            return highlightTint
        case .upcoming:
            return ConsolePalette.mutedText
        }
    }

    private var detailTint: Color {
        phase == .upcoming ? ConsolePalette.mutedText : ConsolePalette.secondaryText
    }

    private var borderTint: Color {
        switch phase {
        case .complete:
            return ConsolePalette.signal
        case .current:
            return highlightTint
        case .upcoming:
            return ConsolePalette.divider
        }
    }

    private var highlightTint: Color {
        requirement == .claudeAccess ? ConsolePalette.accent : ConsolePalette.warning
    }

    private var connectorHeight: CGFloat {
        if isExpanded {
            return requirement == .claudeAccess ? 148 : 72
        }
        return 52
    }
}

private func primaryButton(title: String, tint: Color, disabled: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(ConsolePalette.background)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(disabled ? ConsolePalette.mutedText : tint)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    .buttonStyle(.plain)
    .disabled(disabled)
}

private func secondaryButton(title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(ConsolePalette.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(ConsolePalette.panelRaised)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(ConsolePalette.divider, lineWidth: 1)
            )
    }
    .buttonStyle(.plain)
}

/// Post-completion enhancement: lets the user opt into having
/// `~/.duoduo-manager/bin` on their interactive shell PATH so agent
/// subprocesses can resolve `duoduo`. Gated on the installed duoduo
/// version actually honoring `DUODUO_NODE_BIN`.
private struct AgentShellPathPanel: View {
    let duoduoVersion: String?

    @State private var status: ShellPathInstaller.Status = .notInstalled
    @State private var errorMessage: String?
    @State private var isBusy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.Onboard.ShellPath.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ConsolePalette.primaryText)

                Spacer()

                statePill
            }

            Text(L10n.Onboard.ShellPath.summary)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ConsolePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let gateMessage {
                Text(gateMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ConsolePalette.warning)
            } else {
                actionRow
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ConsolePalette.critical)
            }
        }
        .padding(14)
        .background(ConsolePalette.panelRaised)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ConsolePalette.divider, lineWidth: 1)
        )
        .task {
            status = ShellPathInstaller.detect()
        }
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

    private var statePill: some View {
        let label: String
        let tint: Color
        switch status {
        case .installed:
            label = L10n.Onboard.ShellPath.stateInstalled
            tint = ConsolePalette.signal
        case .notInstalled:
            label = L10n.Onboard.ShellPath.stateNotInstalled
            tint = ConsolePalette.mutedText
        case .partiallyInstalled:
            label = L10n.Onboard.ShellPath.statePartial
            tint = ConsolePalette.warning
        }
        return Text(label)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: 10) {
            switch status {
            case .installed:
                secondaryButton(title: L10n.Onboard.ShellPath.actionRefresh, action: refresh)
                secondaryButton(title: L10n.Onboard.ShellPath.actionRemove, action: remove)
            case .notInstalled, .partiallyInstalled:
                primaryButton(
                    title: L10n.Onboard.ShellPath.actionInstall,
                    tint: ConsolePalette.accent,
                    disabled: isBusy,
                    action: install
                )
                if status == .partiallyInstalled {
                    secondaryButton(title: L10n.Onboard.ShellPath.actionRemove, action: remove)
                }
            }
        }
    }

    private func install() {
        run {
            try ShellPathInstaller.install()
            status = ShellPathInstaller.detect()
        }
    }

    private func refresh() { install() }

    private func remove() {
        run {
            try ShellPathInstaller.uninstall()
            status = ShellPathInstaller.detect()
        }
    }

    private func run(_ work: () throws -> Void) {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try work()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

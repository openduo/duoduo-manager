import XCTest
@testable import DuoduoManager

@MainActor
final class OnboardingStoreTests: XCTestCase {
    func testHydrateSettingsFailureStartsDetectionAndPreservesError() async {
        let dependencies = OnboardingStoreDependencies(
            currentEnv: { throw ClaudeCLIError.invalidSettingsFile },
            detect: { _, _, _, _ in
                OnboardingSnapshot(
                    duoduoInstalled: false,
                    duoduoVersion: nil,
                    claudeInstalled: false,
                    claudeVersion: nil,
                    claudeAuthenticated: false,
                    claudeAuthMethod: nil,
                    claudeAPIProvider: nil,
                    daemonHealthy: false,
                    daemonPID: nil
                )
            },
            installDuoduo: { _ in "" },
            installClaude: { _ in },
            authStatus: { ClaudeAuthStatus(loggedIn: false, authMethod: nil, apiProvider: nil) },
            login: {},
            mergeProviderEnv: { _ in }
        )
        let store = OnboardingStore(dependencies: dependencies)

        await store.run(.hydrateSettings)
        await waitFor { store.state.step == .ready }

        XCTAssertTrue(store.state.hydratedSettings)
        XCTAssertNil(store.state.errorMessage)
        XCTAssertEqual(store.state.statusMessage, L10n.Onboard.statusDetecting)
        XCTAssertEqual(store.state.currentRequirement, .duoduoCLI)
    }

    func testDetectRefreshesRuntimeBeforeComputingSnapshot() async {
        let runtime = RuntimeStore(
            status: .empty,
            daemonConfig: DaemonConfig(workDir: "", daemonHost: "127.0.0.1", port: "20233", logLevel: "info", permissionMode: "default"),
            feishuConfig: FeishuConfig()
        )
        let appStore = AppStore(
            runtime: runtime,
            dashboard: DashboardStore(),
            updates: UpdateStore(),
            command: CommandStore(),
            dependencies: TestFactory.dependencies(
                daemonStatus: DaemonStatus(isRunning: true, version: "", pid: "88", output: "ok", lastUpdated: .now),
                daemonVersion: "0.5.0"
            )
        )
        let dependencies = OnboardingStoreDependencies(
            currentEnv: { [:] },
            detect: { appStore, _, _, _ in
                XCTAssertEqual(appStore?.runtime.status.version, "0.5.0")
                XCTAssertEqual(appStore?.runtime.status.pid, "88")
                return OnboardingSnapshot(
                    duoduoInstalled: true,
                    duoduoVersion: appStore?.runtime.status.version,
                    claudeInstalled: false,
                    claudeVersion: nil,
                    claudeAuthenticated: false,
                    claudeAuthMethod: nil,
                    claudeAPIProvider: nil,
                    daemonHealthy: true,
                    daemonPID: appStore?.runtime.status.pid
                )
            },
            installDuoduo: { _ in "" },
            installClaude: { _ in },
            authStatus: { ClaudeAuthStatus(loggedIn: false, authMethod: nil, apiProvider: nil) },
            login: {},
            mergeProviderEnv: { _ in }
        )
        let store = OnboardingStore(appStore: appStore, dependencies: dependencies)

        await store.run(.detect(status: "detecting"))

        XCTAssertEqual(store.state.snapshot.duoduoVersion, "0.5.0")
        XCTAssertEqual(store.state.currentRequirement, .claudeCLI)
        XCTAssertEqual(store.state.statusMessage, "detecting")
    }

    func testInstallDuoduoSuccessTriggersRefreshDetection() async {
        let dependencies = OnboardingStoreDependencies(
            currentEnv: { [:] },
            detect: { _, _, _, _ in
                OnboardingSnapshot(
                    duoduoInstalled: true,
                    duoduoVersion: "0.5.0",
                    claudeInstalled: false,
                    claudeVersion: nil,
                    claudeAuthenticated: false,
                    claudeAuthMethod: nil,
                    claudeAPIProvider: nil,
                    daemonHealthy: false,
                    daemonPID: nil
                )
            },
            installDuoduo: { useMirror in
                XCTAssertTrue(useMirror)
                return "installed"
            },
            installClaude: { _ in },
            authStatus: { ClaudeAuthStatus(loggedIn: false, authMethod: nil, apiProvider: nil) },
            login: {},
            mergeProviderEnv: { _ in }
        )
        let store = OnboardingStore(dependencies: dependencies)

        await store.run(.installDuoduo(useMirror: true))
        await waitFor { store.state.snapshot.duoduoInstalled }

        XCTAssertEqual(store.state.currentRequirement, .claudeCLI)
        XCTAssertEqual(store.state.statusMessage, L10n.Onboard.statusRedetecting)
    }

    func testInstallClaudeFailureSurfacesLocalizedError() async {
        struct InstallError: LocalizedError {
            var errorDescription: String? { "claude install failed" }
        }
        let dependencies = OnboardingStoreDependencies(
            currentEnv: { [:] },
            detect: { _, _, _, _ in .empty },
            installDuoduo: { _ in "" },
            installClaude: { _ in throw InstallError() },
            authStatus: { ClaudeAuthStatus(loggedIn: false, authMethod: nil, apiProvider: nil) },
            login: {},
            mergeProviderEnv: { _ in }
        )
        let store = OnboardingStore(dependencies: dependencies)

        await store.run(.installClaude(useMirror: false))

        XCTAssertEqual(store.state.errorMessage, "claude install failed")
        XCTAssertFalse(store.state.isBusy)
    }

    func testVerifyClaudeStatusLoggedInCompletesFlow() async {
        let dependencies = OnboardingStoreDependencies(
            currentEnv: { [:] },
            detect: { _, knownClaudeInstalled, _, knownClaudeAuthStatus in
                XCTAssertEqual(knownClaudeInstalled, true)
                XCTAssertEqual(knownClaudeAuthStatus?.loggedIn, true)
                return OnboardingSnapshot(
                    duoduoInstalled: true,
                    duoduoVersion: "0.5.0",
                    claudeInstalled: true,
                    claudeVersion: "1.2.0",
                    claudeAuthenticated: true,
                    claudeAuthMethod: "api-key",
                    claudeAPIProvider: "official",
                    daemonHealthy: true,
                    daemonPID: "42"
                )
            },
            installDuoduo: { _ in "" },
            installClaude: { _ in },
            authStatus: { ClaudeAuthStatus(loggedIn: true, authMethod: "api-key", apiProvider: "official") },
            login: {},
            mergeProviderEnv: { _ in }
        )
        let store = OnboardingStore(dependencies: dependencies)

        await store.run(.verifyClaudeStatus)

        XCTAssertEqual(store.state.step, .complete)
        XCTAssertEqual(store.state.statusMessage, L10n.Onboard.statusLlmVerified)
        XCTAssertNil(store.state.errorMessage)
    }

    func testSaveProviderConfigReportsAuthFailureAfterWritingSettings() async {
        final class Recorder {
            var mergedEnv: [String: String] = [:]
        }
        let recorder = Recorder()
        let dependencies = OnboardingStoreDependencies(
            currentEnv: { [:] },
            detect: { _, _, _, _ in XCTFail("detect should not run when auth fails"); return .empty },
            installDuoduo: { _ in "" },
            installClaude: { _ in },
            authStatus: { ClaudeAuthStatus(loggedIn: false, authMethod: nil, apiProvider: nil) },
            login: {},
            mergeProviderEnv: { env in recorder.mergedEnv = env }
        )
        let store = OnboardingStore(dependencies: dependencies)

        await store.run(.saveProviderConfig(envVars: ["ANTHROPIC_AUTH_TOKEN": "secret"], successStatus: "saved"))

        XCTAssertEqual(recorder.mergedEnv["ANTHROPIC_AUTH_TOKEN"], "secret")
        XCTAssertEqual(store.state.errorMessage, L10n.Onboard.errConfigSavedButAuthFailed)
        XCTAssertNotEqual(store.state.step, .complete)
    }

    func testPerformOAuthLoginFailureSurfacesError() async {
        struct ExpectedError: LocalizedError {
            var errorDescription: String? { "login exploded" }
        }
        let dependencies = OnboardingStoreDependencies(
            currentEnv: { [:] },
            detect: { _, _, _, _ in .empty },
            installDuoduo: { _ in "" },
            installClaude: { _ in },
            authStatus: { ClaudeAuthStatus(loggedIn: false, authMethod: nil, apiProvider: nil) },
            login: { throw ExpectedError() },
            mergeProviderEnv: { _ in }
        )
        let store = OnboardingStore(dependencies: dependencies)

        await store.run(.performOAuthLogin)

        XCTAssertEqual(store.state.errorMessage, "login exploded")
        XCTAssertFalse(store.state.isBusy)
    }

    func testStartDaemonRefreshesRuntimeAndCompletesWhenHealthy() async {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let envURL = tempRoot
            .appendingPathComponent("config", isDirectory: true)
            .appendingPathComponent("duoduo", isDirectory: true)
            .appendingPathComponent(".env", isDirectory: false)
        let workDir = tempRoot.appendingPathComponent("work", isDirectory: true).path
        ConfigStore.envURLOverride = envURL
        OnboardingCompletionMarker.homeDirectoryOverride = tempRoot.path
        defer {
            ConfigStore.envURLOverride = nil
            OnboardingCompletionMarker.homeDirectoryOverride = nil
            try? FileManager.default.removeItem(at: tempRoot)
        }
        let runtime = RuntimeStore(
            status: .empty,
            daemonConfig: DaemonConfig(workDir: "", daemonHost: "127.0.0.1", port: "20233", logLevel: "info", permissionMode: "default"),
            feishuConfig: FeishuConfig()
        )
        let appStore = AppStore(
            runtime: runtime,
            dashboard: DashboardStore(),
            updates: UpdateStore(),
            command: CommandStore(),
            dependencies: TestFactory.dependencies(
                daemonStatus: DaemonStatus(isRunning: true, version: "", pid: "2468", output: "ok", lastUpdated: .now),
                daemonVersion: "0.4.8"
            )
        )
        let dependencies = OnboardingStoreDependencies(
            currentEnv: { [:] },
            detect: { appStore, _, _, _ in
                XCTAssertTrue(appStore?.runtime.status.isRunning == true)
                return OnboardingSnapshot(
                    duoduoInstalled: true,
                    duoduoVersion: "0.4.8",
                    claudeInstalled: true,
                    claudeVersion: "1.2.0",
                    claudeAuthenticated: true,
                    claudeAuthMethod: nil,
                    claudeAPIProvider: nil,
                    daemonHealthy: true,
                    daemonPID: appStore?.runtime.status.pid
                )
            },
            installDuoduo: { _ in "" },
            installClaude: { _ in },
            authStatus: { ClaudeAuthStatus(loggedIn: true, authMethod: nil, apiProvider: nil) },
            login: {},
            mergeProviderEnv: { _ in }
        )
        let store = OnboardingStore(appStore: appStore, dependencies: dependencies)

        await store.run(.startDaemon(workDir: workDir))

        XCTAssertTrue(appStore.runtime.status.isRunning)
        XCTAssertEqual(appStore.runtime.status.pid, "2468")
        XCTAssertEqual(appStore.runtime.daemonConfig.workDir, workDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: workDir))
        let configURL = tempRoot
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("duoduo", isDirectory: true)
            .appendingPathComponent("config.json", isDirectory: false)
        let configData = try? Data(contentsOf: configURL)
        XCTAssertNotNil(configData)
        let configDocument = configData.flatMap {
            try? JSONDecoder().decode(OnboardingConfigDocument.self, from: $0)
        }
        XCTAssertEqual(configDocument?.workDir, workDir)
        XCTAssertEqual(store.state.step, .complete)
        XCTAssertEqual(store.state.statusMessage, L10n.Onboard.statusDaemonStarted)
    }

    private func waitFor(
        timeout: TimeInterval = 1,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Timed out waiting for condition")
    }
}

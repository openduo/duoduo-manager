import XCTest
@testable import DuoduoManager

@MainActor
final class OnboardingStoreTests: XCTestCase {
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

        await store.run(.startDaemon)

        XCTAssertTrue(appStore.runtime.status.isRunning)
        XCTAssertEqual(appStore.runtime.status.pid, "2468")
        XCTAssertEqual(store.state.step, .complete)
        XCTAssertEqual(store.state.statusMessage, L10n.Onboard.statusDaemonStarted)
    }
}

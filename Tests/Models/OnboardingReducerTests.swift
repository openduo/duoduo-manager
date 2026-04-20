import XCTest
@testable import DuoduoManager

final class OnboardingReducerTests: XCTestCase {
    func testBootstrapStartsHydrationBeforeDetection() {
        var state = OnboardingState()

        let command = OnboardingReducer.reduce(state: &state, event: .bootstrap)

        XCTAssertEqual(command, .hydrateSettings)
        XCTAssertFalse(state.hydratedSettings)
    }

    func testSettingsHydratedStartsDetectionAndHydratesPreset() {
        var state = OnboardingState()
        let env = [
            "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
            "ANTHROPIC_AUTH_TOKEN": "token"
        ]

        let command = OnboardingReducer.reduce(state: &state, event: .settingsHydrated(env))

        XCTAssertEqual(command, .detect(status: L10n.Onboard.statusDetecting))
        XCTAssertEqual(state.selectedPreset, .zai)
        XCTAssertEqual(state.authToken, "token")
        XCTAssertTrue(state.isBusy)
        XCTAssertEqual(state.step, .detecting)
    }

    func testDetectionFinishedWithNoUnmetRequirementsCompletesFlow() {
        var state = OnboardingState()
        let snapshot = OnboardingSnapshot(
            duoduoInstalled: true,
            duoduoVersion: "0.5.0",
            claudeInstalled: true,
            claudeVersion: "1.0.0",
            claudeAuthenticated: true,
            claudeAuthMethod: nil,
            claudeAPIProvider: nil,
            daemonHealthy: true,
            daemonPID: "123"
        )

        let command = OnboardingReducer.reduce(state: &state, event: .detectionFinished(snapshot, status: nil))

        XCTAssertNil(command)
        XCTAssertEqual(state.step, .complete)
        XCTAssertEqual(state.statusMessage, L10n.Onboard.statusSystemReady)
        XCTAssertFalse(state.isBusy)
    }

    func testSaveProviderRequestedReturnsCommandWhenStateCanSave() {
        var state = OnboardingState()
        state.selectedPreset = .custom
        state.authToken = "secret"
        state.customBaseURL = "https://example.com/anthropic"
        state.customModel = "model-x"

        let command = OnboardingReducer.reduce(state: &state, event: .saveProviderRequested)

        guard case .saveProviderConfig(let envVars, _) = command else {
            return XCTFail("expected saveProviderConfig")
        }
        XCTAssertEqual(envVars["ANTHROPIC_AUTH_TOKEN"], "secret")
        XCTAssertEqual(envVars["ANTHROPIC_BASE_URL"], "https://example.com/anthropic")
        XCTAssertEqual(envVars["ANTHROPIC_MODEL"], "model-x")
        XCTAssertTrue(state.isBusy)
    }
}

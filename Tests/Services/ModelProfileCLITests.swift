import XCTest
@testable import DuoduoManager

final class ModelProfileCLITests: XCTestCase {
    func testGetArgumentsUseGlobalFlag() {
        XCTAssertEqual(
            ModelProfileCLI.getArguments(scope: .global),
            ["config", "--global", "profile", "get", "--json"]
        )
    }

    func testGetArgumentsUseKindFlag() {
        XCTAssertEqual(
            ModelProfileCLI.getArguments(scope: .kind("feishu")),
            ["config", "--kind", "feishu", "profile", "get", "--json"]
        )
    }

    func testSetArgumentsNeverContainTheToken() {
        let args = ModelProfileCLI.setArgumentsJSON(
            scope: .global,
            modelID: "deepseek-v4-pro",
            maxContextTokens: 1_000_000,
            baseURL: "https://api.deepseek.com/anthropic",
            authField: .anthropicAuthToken
        )
        XCTAssertEqual(args, [
            "config", "--global", "profile", "set",
            "deepseek-v4-pro", "1000000",
            "--base-url", "https://api.deepseek.com/anthropic",
            "--auth-token-stdin", "--json"
        ])
        XCTAssertFalse(args.contains { $0.contains("sk-") })
    }

    func testWindowOnlySetOmitsRoutingFlags() {
        let args = ModelProfileCLI.setArgumentsJSON(
            scope: .global,
            modelID: "kimi-k2.6",
            maxContextTokens: 262_144,
            baseURL: nil,
            authField: nil
        )
        XCTAssertEqual(args, [
            "config", "--global", "profile", "set", "kimi-k2.6", "262144", "--json"
        ])
    }

    func testOauthUsesOauthStdinFlag() {
        let args = ModelProfileCLI.setArguments(
            scope: .kind("stdio"),
            modelID: "routed-model",
            maxContextTokens: 200_000,
            baseURL: "https://example.test/anthropic",
            authField: .claudeCodeOAuthToken
        )
        XCTAssertTrue(args.contains("--oauth-token-stdin"))
        XCTAssertFalse(args.contains("--auth-token-stdin"))
    }
}

final class ModelProfileValidationTests: XCTestCase {
    func testRejectsNativeClaudeAndOneMSuffix() {
        XCTAssertEqual(ModelProfileValidation.modelID("claude-opus-4"), .nativeClaudeID)
        XCTAssertEqual(ModelProfileValidation.modelID("deepseek-v4-pro[1m]"), .oneMSuffix)
        XCTAssertEqual(ModelProfileValidation.modelID("has space"), .modelIDWhitespace)
        XCTAssertNil(ModelProfileValidation.modelID("deepseek-v4-pro"))
    }

    func testRejectsNonPositiveTokens() {
        XCTAssertEqual(ModelProfileValidation.tokens("0").1, .tokensNotPositive)
        XCTAssertEqual(ModelProfileValidation.tokens("abc").1, .tokensNotPositive)
        XCTAssertEqual(ModelProfileValidation.tokens("1000000").0, 1_000_000)
    }

    func testRejectsCredentialInBaseURL() {
        XCTAssertEqual(
            ModelProfileValidation.baseURL("https://user:pass@api.example.com/anthropic"),
            .baseURLCarriesCredentials
        )
        XCTAssertEqual(ModelProfileValidation.baseURL("not a url"), .invalidBaseURL)
        XCTAssertNil(ModelProfileValidation.baseURL("https://api.deepseek.com/anthropic"))
    }

    func testRoutedDraftRequiresTokenEvenWhenMaskedCredentialExists() {
        var draft = ModelProfileDraft.from(
            ModelProfileEntry(
                model: "deepseek-v4-pro",
                max_context_tokens: 1_000_000,
                base_url: "https://api.deepseek.com/anthropic",
                auth: ModelProfileAuth(field: "anthropic_auth_token", masked: "…1234"),
                source: "global"
            )
        )
        XCTAssertTrue(draft.validate().contains(.routedMissingToken))
        draft.token = "sk-test-token"
        XCTAssertTrue(draft.validate().isEmpty)
    }

    func testWindowOnlyDraftDoesNotRequireToken() {
        let draft = ModelProfileDraft(
            originalModelID: nil,
            modelID: "kimi-k2.6",
            tokensText: "262144",
            routeToEndpoint: false,
            baseURL: "",
            authField: .anthropicAuthToken,
            token: "",
            existingAuthMasked: nil
        )
        XCTAssertTrue(draft.validate().isEmpty)
    }
}

final class SessionConfigJSONTests: XCTestCase {
    func testDecodesLayerProfileGet() throws {
        let json = """
        {
          "ok": true,
          "verb": "profile_get",
          "scope": "global",
          "config": [],
          "profiles": {
            "view": "layer",
            "entries": [
              {
                "model": "deepseek-v4-pro",
                "max_context_tokens": 1000000,
                "base_url": "https://api.deepseek.com/anthropic",
                "auth": { "field": "anthropic_auth_token", "masked": "…9xyz" },
                "source": "global"
              }
            ],
            "aliases": [
              { "tier": "opus", "model": "deepseek-v4-pro", "source": "global" }
            ],
            "issues": []
          }
        }
        """
        let result = try SessionConfigJSON.decodeResult(from: json)
        let snapshot = result.snapshot(fallbackScope: .kind("feishu"))
        XCTAssertEqual(snapshot.scope, .global)
        XCTAssertEqual(snapshot.entries.count, 1)
        XCTAssertEqual(snapshot.entries[0].model, "deepseek-v4-pro")
        XCTAssertEqual(snapshot.entries[0].max_context_tokens, 1_000_000)
        XCTAssertEqual(snapshot.entries[0].auth?.masked, "…9xyz")
        XCTAssertEqual(snapshot.aliasModel(for: "opus"), "deepseek-v4-pro")
        XCTAssertNil(snapshot.entries[0].auth?.masked.range(of: "sk-"))
    }

    func testExtractsJSONFromShellErrorMixture() throws {
        let mixed = """
        {"ok":false,"reason":"invalid","errors":["model id has whitespace"]}
        [stderr]
        error: daemon rejected session.config
        """
        let result = try SessionConfigJSON.decodeResult(from: mixed)
        XCTAssertFalse(result.ok)
        XCTAssertEqual(result.failureMessage, "model id has whitespace")
    }
}

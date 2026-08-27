import Foundation

struct ModelProfileScopeOption: Identifiable, Hashable {
    var id: String { scope.id }
    let scope: ModelProfileScope
    let title: String
    let detail: String
}

struct ModelProfileRowPresentation: Identifiable {
    var id: String { modelID }
    let modelID: String
    let tokensLabel: String
    let endpointLabel: String
    let authLabel: String
    let isRouted: Bool
}

struct ModelProfileAliasRowPresentation: Identifiable {
    var id: String { tier }
    let tier: String
    let modelID: String
}

struct ModelProfilesPresentation {
    let scopeOptions: [ModelProfileScopeOption]
    let selectedScopeID: String
    let rows: [ModelProfileRowPresentation]
    let aliasRows: [ModelProfileAliasRowPresentation]
    let issues: [String]
    let isLoading: Bool
    let isSaving: Bool
    let errorMessage: String?
    let infoMessage: String?
    let isEmpty: Bool
}

@MainActor
enum ModelProfilePresentationMapper {
    static func make(store: ModelProfileStore) -> ModelProfilesPresentation {
        ModelProfilesPresentation(
            scopeOptions: store.availableScopes.map(scopeOption),
            selectedScopeID: store.scope.id,
            rows: store.snapshot.entries.map(row),
            aliasRows: ModelProfileCLI.aliasTiers.map { tier in
                ModelProfileAliasRowPresentation(
                    tier: tier,
                    modelID: store.snapshot.aliasModel(for: tier)
                )
            },
            issues: store.snapshot.issues.map(issueText),
            isLoading: store.isLoading,
            isSaving: store.isSaving,
            errorMessage: store.errorMessage,
            infoMessage: store.infoMessage,
            isEmpty: store.snapshot.entries.isEmpty
        )
    }

    static func scopeOption(_ scope: ModelProfileScope) -> ModelProfileScopeOption {
        switch scope {
        case .global:
            return ModelProfileScopeOption(
                scope: .global,
                title: L10n.ModelProfiles.scopeGlobal,
                detail: L10n.ModelProfiles.scopeGlobalDetail
            )
        case .kind(let kind):
            return ModelProfileScopeOption(
                scope: .kind(kind),
                title: kind,
                detail: L10n.ModelProfiles.scopeKindDetail(kind)
            )
        }
    }

    static func row(_ entry: ModelProfileEntry) -> ModelProfileRowPresentation {
        let endpoint: String
        if let url = entry.base_url, let host = URL(string: url)?.host, !host.isEmpty {
            endpoint = host
        } else if let url = entry.base_url, !url.isEmpty {
            endpoint = url
        } else {
            endpoint = L10n.ModelProfiles.hostEndpoint
        }

        let auth: String
        if let masked = entry.auth {
            auth = "\(masked.field): \(masked.masked)"
        } else {
            auth = "—"
        }

        return ModelProfileRowPresentation(
            modelID: entry.model,
            tokensLabel: tokensLabel(entry.max_context_tokens),
            endpointLabel: endpoint,
            authLabel: auth,
            isRouted: entry.isRouted
        )
    }

    static func tokensLabel(_ tokens: Int) -> String {
        let formatted = tokens.formatted(.number.grouping(.automatic))
        return L10n.ModelProfiles.tokenCount(formatted)
    }

    static func issueText(_ issue: ModelProfileIssue) -> String {
        let model = issue.model ?? "—"
        let layer = issue.layer ?? "—"
        return L10n.ModelProfiles.rejectedEntry(model, issue.reason, layer)
    }
}

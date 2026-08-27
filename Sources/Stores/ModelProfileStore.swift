import Foundation

@MainActor
@Observable
final class ModelProfileStore {
    var sessionService: any SessionServicing
    var scope: ModelProfileScope = .global
    var snapshot: ModelProfileSnapshot = .empty
    var availableScopes: [ModelProfileScope] = [.global]
    var isLoading = false
    var isSaving = false
    var errorMessage: String?
    var infoMessage: String?

    init(sessionService: any SessionServicing) {
        self.sessionService = sessionService
    }

    func reload(
        installedVersion: String?,
        daemonRunning: Bool,
        channels: [ChannelInfo]
    ) async {
        availableScopes = Self.scopes(channels: channels)
        if !availableScopes.contains(scope) {
            scope = .global
        }

        errorMessage = nil
        infoMessage = nil

        guard DuoduoCompat.meetsMinimum(
            installed: installedVersion,
            minimum: DuoduoCompat.minVersionForModelProfiles
        ) else {
            snapshot = .empty
            errorMessage = ModelProfileError.unsupportedCLI(
                installed: installedVersion,
                minimum: DuoduoCompat.minVersionForModelProfiles
            ).localizedDescription
            return
        }

        guard daemonRunning else {
            snapshot = .empty
            errorMessage = ModelProfileError.daemonNotRunning.localizedDescription
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            snapshot = try await sessionService.profileGet(scope: scope)
            infoMessage = Self.advisory(from: snapshot)
        } catch {
            snapshot = .empty
            errorMessage = error.localizedDescription
        }
    }

    func save(_ draft: ModelProfileDraft) async -> Bool {
        let issues = draft.validate()
        if !issues.isEmpty {
            errorMessage = ModelProfileError.validation(issues).localizedDescription
            return false
        }

        isSaving = true
        defer { isSaving = false }
        errorMessage = nil
        do {
            let auth = draft.authInput
            snapshot = try await sessionService.profileSet(
                scope: scope,
                modelID: draft.trimmedModelID,
                maxContextTokens: draft.parsedTokens,
                baseURL: draft.trimmedBaseURL,
                authField: auth?.field,
                authToken: auth?.token
            )
            infoMessage = Self.advisory(from: snapshot) ?? L10n.ModelProfiles.saved
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete(modelID: String) async {
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil
        do {
            snapshot = try await sessionService.profileUnset(scope: scope, modelID: modelID)
            infoMessage = L10n.ModelProfiles.removed(modelID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveAlias(tier: String, modelID: String) async {
        let trimmed = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil
        do {
            if trimmed.isEmpty {
                snapshot = try await sessionService.profileAliasUnset(scope: scope, tier: tier)
            } else {
                snapshot = try await sessionService.profileAliasSet(
                    scope: scope,
                    tier: tier,
                    modelID: trimmed
                )
            }
            infoMessage = Self.advisory(from: snapshot) ?? L10n.ModelProfiles.aliasSaved
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func scopes(channels: [ChannelInfo]) -> [ModelProfileScope] {
        var kinds: [String] = ["stdio"]
        for channel in channels where !kinds.contains(channel.type) {
            kinds.append(channel.type)
        }
        if !kinds.contains("job") {
            kinds.append("job")
        }
        return [.global] + kinds.map { .kind($0) }
    }

    static func advisory(from snapshot: ModelProfileSnapshot) -> String? {
        var lines: [String] = []
        if let conflict = snapshot.settingsEnvConflict {
            lines.append(L10n.ModelProfiles.settingsConflict(conflict.file, conflict.value))
        }
        if let warning = snapshot.aliasEndpointWarning {
            let model = warning.model ?? ""
            let target = warning.target_base_url ?? L10n.ModelProfiles.hostEndpoint
            lines.append(L10n.ModelProfiles.aliasEndpointWarning(model, target))
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}

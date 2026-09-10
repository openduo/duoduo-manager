import Foundation

enum CommandOperation: Equatable {
    case upgradeAll
    case installSkills
    case autostart
}

@MainActor
@Observable
final class CommandStore {
    var isLoading: Bool
    var activeOperation: CommandOperation?
    var lastOutput: String
    var errorMessage: String?
    var upgradeTarget: UpgradeTarget?

    init(
        isLoading: Bool = false,
        activeOperation: CommandOperation? = nil,
        lastOutput: String = "",
        errorMessage: String? = nil,
        upgradeTarget: UpgradeTarget? = nil
    ) {
        self.isLoading = isLoading
        self.activeOperation = activeOperation
        self.lastOutput = lastOutput
        self.errorMessage = errorMessage
        self.upgradeTarget = upgradeTarget
    }
}

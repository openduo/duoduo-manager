import Foundation

enum CommandOperation: Equatable {
    case upgradeAll
}

@MainActor
@Observable
final class CommandStore {
    var isLoading: Bool
    var activeOperation: CommandOperation?
    var lastOutput: String
    var errorMessage: String?

    init(
        isLoading: Bool = false,
        activeOperation: CommandOperation? = nil,
        lastOutput: String = "",
        errorMessage: String? = nil
    ) {
        self.isLoading = isLoading
        self.activeOperation = activeOperation
        self.lastOutput = lastOutput
        self.errorMessage = errorMessage
    }
}

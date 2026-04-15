import Foundation

@MainActor
@Observable
final class CommandStore {
    var isLoading: Bool
    var lastOutput: String
    var errorMessage: String?

    init(
        isLoading: Bool = false,
        lastOutput: String = "",
        errorMessage: String? = nil
    ) {
        self.isLoading = isLoading
        self.lastOutput = lastOutput
        self.errorMessage = errorMessage
    }
}

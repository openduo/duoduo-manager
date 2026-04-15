import SwiftUI

struct StatusHeaderPresentation {
    let runtimeLive: Bool
    let controlBusy: Bool
    let eventCount: Int
    let showAppUpdate: Bool
    let appVersion: String
    let showRuntimeUpdate: Bool
    let isLoading: Bool
}

struct StatusTopologyPresentation {
    let endpoint: String
    let runtimeHost: String
    let process: String
    let system: String
    let systemTint: Color
    let subconsciousRows: [SummaryRowData]
}

struct StatusServiceCardPresentation {
    let icon: String
    let name: String
    let version: String
    let hasUpdate: Bool
    let latestVersion: String
    let pid: String
    let isRunning: Bool
    let isLoading: Bool
}

struct StatusInstallCardPresentation {
    let iconName: String
    let name: String
    let packageName: String
    let isLoading: Bool
}

struct StatusRuntimeStreamPresentation {
    let hint: String
    let lastOutput: String
    let errorMessage: String?
    let recentEvents: [SpineEvent]
    let expandedEventIDs: Set<String>
}

struct StatusExecutionPresentation {
    let hint: String
    let sessionCaption: String
    let jobCaption: String
    let sessionRows: [SummaryRowData]
    let jobRows: [SummaryRowData]
}

struct StatusFooterPresentation {
    let sessionLoad: Int
    let eventFlow: Int
}

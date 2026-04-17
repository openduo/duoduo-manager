import SwiftUI

struct StatusBarPresentationBundle {
    let header: StatusHeaderPresentation
    let topology: StatusTopologyPresentation
    let daemonCard: StatusServiceCardPresentation
    let stream: StatusRuntimeStreamPresentation
    let execution: StatusExecutionPresentation
    let footer: StatusFooterPresentation
    let controlHint: String
}

struct StatusHeaderPresentation {
    let runtimeLive: Bool
    let controlBusy: Bool
    let eventCount: Int
    let showAppUpdate: Bool
    let appVersion: String
    let showRuntimeUpdate: Bool
    let isLoading: Bool
    let currentVersion: String
}

struct StatusTopologyPresentation {
    let endpoint: String
    let runtimeHost: String
    let system: String
    let systemTint: Color
    let load: String
    let loadTint: Color
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
    let costValue: String
    let tokenValue: String
    let cacheValue: String
    let toolsValue: String
    let statusMessage: String?
    let statusIsError: Bool
}

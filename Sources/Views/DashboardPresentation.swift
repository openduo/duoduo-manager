import SwiftUI

struct DashboardSidebarGroupPresentation: Identifiable {
    let id: String
    let key: String
    let label: String
    let count: Int
    let eventTypes: [DashboardEventTypePresentation]
}

struct DashboardEventTypePresentation: Identifiable {
    let id: String
    let type: String
    let shortName: String
    let count: Int
    let color: Color
}

struct DashboardBottomStatsPresentation {
    let costText: String
    let tokenText: String
    let cacheText: String
    let toolText: String
    let subconsciousItems: [DashboardSubconsciousItemPresentation]
    let healthText: String
    let healthColor: Color
}

struct DashboardSubconsciousItemPresentation: Identifiable {
    let id: String
    let marker: String
    let name: String
    let markerColor: Color
    let textColor: Color
}

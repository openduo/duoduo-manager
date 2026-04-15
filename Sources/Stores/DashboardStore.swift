import Foundation

@MainActor
@Observable
final class DashboardStore {
    var sessions: [SessionInfo]
    var health: HealthInfo?
    var subconscious: SubconsciousInfo?
    var cadence: CadenceInfo?
    var jobs: [JobInfo]
    var events: [SpineEvent]
    var totalCost: Double
    var totalTokens: Int
    var totalTools: Int
    var cacheHitRate: Int
    var config: SystemConfig?

    init(
        sessions: [SessionInfo] = [],
        health: HealthInfo? = nil,
        subconscious: SubconsciousInfo? = nil,
        cadence: CadenceInfo? = nil,
        jobs: [JobInfo] = [],
        events: [SpineEvent] = [],
        totalCost: Double = 0,
        totalTokens: Int = 0,
        totalTools: Int = 0,
        cacheHitRate: Int = 0,
        config: SystemConfig? = nil
    ) {
        self.sessions = sessions
        self.health = health
        self.subconscious = subconscious
        self.cadence = cadence
        self.jobs = jobs
        self.events = events
        self.totalCost = totalCost
        self.totalTokens = totalTokens
        self.totalTools = totalTools
        self.cacheHitRate = cacheHitRate
        self.config = config
    }
}

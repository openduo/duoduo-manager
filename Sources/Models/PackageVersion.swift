import Foundation

struct PackageVersion: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let installedVersion: String?
    let latestVersion: String
    let needsUpdate: Bool
}

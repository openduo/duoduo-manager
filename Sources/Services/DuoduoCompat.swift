import Foundation

/// Single source of truth for compatibility constants tied to specific
/// upstream `@openduo/duoduo` capabilities. When a capability lands in a
/// new duoduo version, update the corresponding `min*` constant here —
/// no other file should hardcode these version numbers.
enum DuoduoCompat {
    /// Environment variable the upstream `bin/duoduo` wrapper reads to
    /// pin a specific Node.js binary, bypassing PATH-based resolution.
    /// See openduo/duoduo#50.
    static let nodeBinEnvVar = "DUODUO_NODE_BIN"

    /// Minimum installed duoduo version that honors `DUODUO_NODE_BIN`.
    /// Below this, exporting the variable is a silent no-op (older
    /// wrappers ignore it), so injection is always backward-safe — but
    /// any feature that *depends* on the wrapper actually using it must
    /// gate on this version.
    ///
    /// Set to the first tagged 0.5.0 release candidate that includes
    /// the wrapper change merged in 0.5.0-pre.22.
    static let minVersionForNodeBinEnv = "0.5.0-rc.1"

    /// Returns true if `installed` is at or above `minimum` under a
    /// simplified semver order: compare the numeric `MAJOR.MINOR.PATCH`
    /// triple first; if equal, a build with a pre-release suffix
    /// (e.g. `-pre.22`, `-rc1`) is considered earlier than the same
    /// triple with no suffix; pre-release suffixes against each other
    /// are compared lexicographically (good enough for `pre.N` and
    /// `rcN` ordering as long as both sides use the same scheme).
    /// Empty / unparseable inputs return false (assume too old).
    static func meetsMinimum(installed: String?, minimum: String) -> Bool {
        guard let installed, !installed.isEmpty else { return false }
        let lhs = parseVersion(installed)
        let rhs = parseVersion(minimum)
        if lhs.triple != rhs.triple {
            return lhs.triple.lexicographicallyPrecedes(rhs.triple) == false
        }
        switch (lhs.preRelease, rhs.preRelease) {
        case (nil, nil): return true
        case (nil, _?): return true   // released > any pre-release of same triple
        case (_?, nil): return false  // pre-release < released of same triple
        case let (l?, r?): return l.compare(r, options: .numeric) != .orderedAscending
        }
    }

    private static func parseVersion(_ raw: String) -> (triple: [Int], preRelease: String?) {
        let parts = raw.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let core = String(parts[0])
        let preRelease = parts.count > 1 ? String(parts[1]) : nil
        let triple = core.split(separator: ".").prefix(3).map { Int($0) ?? 0 }
        let padded = triple + Array(repeating: 0, count: max(0, 3 - triple.count))
        return (padded, preRelease)
    }
}

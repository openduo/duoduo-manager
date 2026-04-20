import Foundation

/// Manages a marked block in the user's shell startup files that
/// prepends `~/.duoduo-manager/bin` to PATH so interactive shells —
/// including the `bash -lc` / `zsh -lc` invocations made by agent
/// subprocesses — can resolve `duoduo`.
///
/// Why we touch shell rc files at all: the manager-private npm prefix
/// is by design unknown to the user's interactive shell. Without a one-
/// time opt-in to expose `~/.duoduo-manager/bin`, no login shell will
/// ever find `duoduo`, regardless of what env the daemon transmits.
///
/// The block is self-disabling: the export is gated on
/// `[ -d "$HOME/.duoduo-manager/bin" ]`, so removing the manager
/// directory leaves no stale PATH entry behind.
struct ShellPathInstaller {
    enum Status: Equatable {
        case notInstalled
        case installed
        case partiallyInstalled  // present in some target files but not others
    }

    enum Failure: LocalizedError {
        case readFailed(path: String, underlying: Error)
        case writeFailed(path: String, underlying: Error)

        var errorDescription: String? {
            switch self {
            case .readFailed(let path, let underlying):
                return "Could not read \(path): \(underlying.localizedDescription)"
            case .writeFailed(let path, let underlying):
                return "Could not update \(path): \(underlying.localizedDescription)"
            }
        }
    }

    static let beginMarker = "# >>> duoduo-manager (managed) >>>"
    static let endMarker = "# <<< duoduo-manager (managed) <<<"

    /// Files we manage. We target the *login*-shell startup files
    /// because the failing scenario is a daemon-spawned `bash -lc` /
    /// `zsh -lc` invocation: those run as login shells but not as
    /// interactive shells, so `~/.zshrc` (interactive-only) is the
    /// wrong file.
    ///
    /// `install` and `detect` / `uninstall` use **different** file
    /// lists on purpose:
    ///
    /// - `installTargets` is the single bash file we *write* to,
    ///   chosen by bash's own startup-file precedence so we never
    ///   silently shadow what bash is already sourcing.
    /// - `bashScanCandidates` is *every* bash login file; detect and
    ///   uninstall walk all of them so a previously installed block
    ///   doesn't become orphaned if the precedence target shifts
    ///   later (e.g. user creates `~/.bash_profile` after we wrote to
    ///   `~/.profile`).
    ///
    /// We intentionally do not touch `/etc/*` files — managing
    /// user-level state needs no sudo.
    static let zshTarget = "~/.zprofile"

    /// All bash login startup files, in bash's own precedence order.
    /// bash sources the first one that exists; we list them in the
    /// same order so callers can pick deterministically.
    static let bashScanCandidates: [String] = [
        "~/.bash_profile",
        "~/.bash_login",
        "~/.profile",
    ]

    /// Files we *install into*. For bash, we write to whichever of
    /// `bashScanCandidates` already exists (to preserve bash's own
    /// precedence) or create `~/.bash_profile` if none do.
    static var installTargets: [String] {
        [zshTarget, bashInstallTarget()]
    }

    /// Files we *scan* for an existing managed block. Always the
    /// full set, regardless of which one a previous install picked,
    /// so detect/uninstall don't lose track of a block when the
    /// precedence target moves under our feet.
    static var allManagedCandidates: [String] {
        [zshTarget] + bashScanCandidates
    }

    private static func bashInstallTarget() -> String {
        // Walk bash's own precedence: first existing wins. This is
        // the file bash itself will source, so writing here is the
        // only way to be guaranteed-effective without shadowing.
        for candidate in bashScanCandidates where pathExists(candidate) {
            return candidate
        }
        // Nothing exists — create the canonical primary.
        return "~/.bash_profile"
    }

    private static func pathExists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: resolve(path))
    }

    /// Installs (or refreshes) the managed block in every install
    /// target. Creates files that don't exist. Idempotent: re-running
    /// replaces the existing block in place rather than appending
    /// duplicates.
    static func install() throws {
        let block = managedBlock()
        for file in installTargets {
            try writeBlock(block, into: file)
        }
    }

    /// Removes the managed block from every candidate file (not just
    /// the current install target), so a block written into a file
    /// that has since lost precedence doesn't survive uninstall.
    /// Files that don't exist or don't contain the block are silently
    /// skipped.
    static func uninstall() throws {
        for file in allManagedCandidates {
            try removeBlock(from: file)
        }
    }

    /// Reports whether the block is present. zsh and bash are
    /// reported independently and aggregated:
    /// - `installed`     iff zsh target has the block AND at least
    ///                   one bash candidate has it
    /// - `notInstalled`  iff neither side has any block anywhere
    /// - `partiallyInstalled` otherwise (zsh-only, bash-only, or
    ///                   bash block in a now-shadowed candidate)
    static func detect() -> Status {
        let zshHasBlock = fileContainsBlock(zshTarget)
        let bashHasBlock = bashScanCandidates.contains(where: fileContainsBlock)
        switch (zshHasBlock, bashHasBlock) {
        case (true, true):   return .installed
        case (false, false): return .notInstalled
        default:             return .partiallyInstalled
        }
    }

    // MARK: - Block content

    /// The full block we insert. Kept self-contained so a reader of
    /// the rc file can understand it without external context.
    static func managedBlock() -> String {
        """
        \(beginMarker)
        # Added by DuoduoManager so agent subprocesses (e.g. claude-code's
        # bash tool) can resolve the `duoduo` CLI installed under the
        # manager's private npm prefix. The directory check makes this
        # a no-op if you uninstall DuoduoManager — no stale PATH entry.
        if [ -d "$HOME/.duoduo-manager/bin" ]; then
            export PATH="$HOME/.duoduo-manager/bin:$PATH"
        fi
        \(endMarker)
        """
    }

    // MARK: - File operations

    private static func resolve(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    private static func fileContainsBlock(_ path: String) -> Bool {
        let resolved = resolve(path)
        guard let content = try? String(contentsOfFile: resolved, encoding: .utf8) else {
            return false
        }
        return content.contains(beginMarker) && content.contains(endMarker)
    }

    private static func writeBlock(_ block: String, into path: String) throws {
        let resolved = resolve(path)
        // Distinguish "file doesn't exist" (we'll create it with just
        // the block) from "file exists but can't be read" (a transient
        // permission or encoding problem). Treating the latter as an
        // empty file would write only the managed block and silently
        // erase the user's shell profile contents.
        let existing: String
        if FileManager.default.fileExists(atPath: resolved) {
            do {
                existing = try String(contentsOfFile: resolved, encoding: .utf8)
            } catch {
                throw Failure.readFailed(path: resolved, underlying: error)
            }
        } else {
            existing = ""
        }

        let updated: String
        if let range = blockRange(in: existing) {
            updated = existing.replacingCharacters(in: range, with: block)
        } else {
            let separator = existing.isEmpty || existing.hasSuffix("\n") ? "" : "\n"
            updated = existing + separator + (existing.isEmpty ? "" : "\n") + block + "\n"
        }

        do {
            try updated.write(toFile: resolved, atomically: true, encoding: .utf8)
        } catch {
            throw Failure.writeFailed(path: resolved, underlying: error)
        }
    }

    private static func removeBlock(from path: String) throws {
        let resolved = resolve(path)
        // Same distinction as `writeBlock`: missing file is a real
        // no-op; existing-but-unreadable file is a real error and must
        // not be silently skipped (otherwise `uninstall` would falsely
        // report success while leaving stale state behind).
        guard FileManager.default.fileExists(atPath: resolved) else { return }
        let existing: String
        do {
            existing = try String(contentsOfFile: resolved, encoding: .utf8)
        } catch {
            throw Failure.readFailed(path: resolved, underlying: error)
        }
        guard let range = blockRange(in: existing) else { return }

        var updated = existing
        updated.removeSubrange(range)
        // Collapse any blank-line padding we may have introduced when
        // first installing, so repeated install/uninstall doesn't grow
        // empty lines without bound.
        while updated.contains("\n\n\n") {
            updated = updated.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        do {
            try updated.write(toFile: resolved, atomically: true, encoding: .utf8)
        } catch {
            throw Failure.writeFailed(path: resolved, underlying: error)
        }
    }

    /// Returns the range from beginMarker through endMarker (inclusive),
    /// or nil if the block isn't present (or markers don't pair up).
    private static func blockRange(in content: String) -> Range<String.Index>? {
        guard let begin = content.range(of: beginMarker),
              let end = content.range(of: endMarker, range: begin.upperBound..<content.endIndex)
        else { return nil }

        // Extend `end` to include the trailing newline of the endMarker
        // line, so removal doesn't leave a dangling blank line.
        var endIndex = end.upperBound
        if endIndex < content.endIndex, content[endIndex] == "\n" {
            endIndex = content.index(after: endIndex)
        }
        return begin.lowerBound..<endIndex
    }
}

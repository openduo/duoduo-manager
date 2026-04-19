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

    /// Files we manage. We target the *login*-shell startup files,
    /// because the failing scenario is a daemon-spawned `bash -lc` /
    /// `zsh -lc` invocation: those run as login shells but not as
    /// interactive shells, so `~/.zshrc` (interactive-only) is the
    /// wrong file.
    ///
    /// For zsh: `~/.zprofile` is unconditional. There is no precedence
    /// trap on the zsh side — login shells always source it (in
    /// addition to `/etc/zprofile`).
    ///
    /// For bash: bash login shells source the *first* of
    /// `~/.bash_profile`, `~/.bash_login`, `~/.profile`. If we
    /// unconditionally created `~/.bash_profile`, we would silently
    /// stop bash from sourcing a pre-existing `~/.profile` — which can
    /// break a user's PATH / env setup (NIX install, asdf, etc. often
    /// land in `~/.profile`). So we pick the bash target dynamically:
    ///   - if `~/.bash_profile` exists → use it (already authoritative)
    ///   - else if `~/.profile` exists → update it (preserve precedence)
    ///   - else → create `~/.bash_profile` (no pre-existing files to
    ///     shadow)
    ///
    /// We intentionally do not touch `/etc/*` files — managing
    /// user-level state needs no sudo.
    static var targetFiles: [String] {
        ["~/.zprofile", bashTargetFile()]
    }

    private static func bashTargetFile() -> String {
        if pathExists("~/.bash_profile") {
            return "~/.bash_profile"
        }
        if pathExists("~/.profile") {
            return "~/.profile"
        }
        return "~/.bash_profile"
    }

    private static func pathExists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: resolve(path))
    }

    /// Installs (or refreshes) the managed block in every target file.
    /// Creates files that don't exist. Idempotent: re-running replaces
    /// the existing block in place rather than appending duplicates.
    static func install() throws {
        let block = managedBlock()
        for file in targetFiles {
            try writeBlock(block, into: file)
        }
    }

    /// Removes the managed block from every target file. Files that
    /// don't exist or don't contain the block are silently skipped.
    static func uninstall() throws {
        for file in targetFiles {
            try removeBlock(from: file)
        }
    }

    /// Reports whether the block is present in target files. Used by
    /// the onboarding panel to render the current state.
    static func detect() -> Status {
        let presence = targetFiles.map { fileContainsBlock($0) }
        if presence.allSatisfy({ $0 }) { return .installed }
        if presence.allSatisfy({ !$0 }) { return .notInstalled }
        return .partiallyInstalled
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

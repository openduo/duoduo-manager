# Feature: Expose `duoduo` to agent subprocess shells (all-in-one mode)

> Working notes for branch `feat/expose-duoduo-in-path`. Pending [openduo/duoduo#50](https://github.com/openduo/duoduo/issues/50) — implementation is gated on a duoduo release that supports `DUODUO_NODE_BIN`.

## Goal

In bundled (`*-with-nodejs`) installs of DuoduoManager, agent subprocesses spawned by the duoduo daemon — including `bash -lc "duoduo …"` invoked from inside agent tool runs — must be able to resolve and execute the `duoduo` CLI.

## Symptom (verified on a real install)

Verified on a real bundled install (`arm64-with-nodejs`, duoduo `0.4.6`):

- The duoduo daemon process (spawned via the `duoduo daemon start` CLI) inherits a PATH that includes `~/.duoduo-manager/bin` and the bundled `…/node/bin`. Inside the daemon, `duoduo` is resolvable.
- Daemon-spawned children (e.g. the `claude` agent runner) also fully inherit that PATH.
- **But** any further `bash -lc "…"` / `zsh -lc "…"` invoked from those children re-runs `/etc/zprofile`, `~/.zprofile`, `~/.zshrc` — which **completely replaces** the inherited PATH with the user's interactive PATH. That user PATH never contains `~/.duoduo-manager/bin` (it's a manager-private prefix the user's shell doesn't know about) nor the `.app`-bundled `node/bin`.
- Net effect: in any login-shell descendant of an agent tool run (the default execution mode of `claude-code`'s Bash tool), `duoduo: command not found`.

## Root cause (after first-principles re-analysis)

Two facts intersect:

1. **`~/.duoduo-manager/` is a private npm prefix** chosen so DuoduoManager doesn't pollute the user's brew/nvm/system Node setup. The price is that the user's interactive shell has no idea this directory exists.
2. **The current `bin/duoduo` (npm-installed wrapper) is a bash script that does `exec node "$ROOT_DIR/dist/release/cli.cjs"`**, so it depends on PATH-resolution of `node`. The wrapper has no way to be told "use this specific node binary."

Once a login-shell rerun strips the inherited PATH, the wrapper can't find either itself (`duoduo`) or its runtime (`node`).

## Why this is unique to bundled all-in-one installs

`universal-lite` users install duoduo themselves into a Node.js prefix that's already on their PATH (brew, nvm, etc.). Their interactive shell finds `duoduo` and `node` natively, so the chain works without any manager intervention. Only the bundled all-in-one mode hits this — it is the mode that keeps everything sandboxed under `~/.duoduo-manager/`.

## Why this *isn't* fixable by env-passthrough alone

We can't fix this by having the daemon push a richer PATH into spawned children's env. The interactive `bash -lc` / `zsh -lc` step blows away whatever the daemon set. The only durable channels are:

1. The user's shell startup files (so `duoduo` gets onto every interactive PATH), and
2. The wrapper learning to find `node` without PATH (so we don't have to inject `node`/`npm` into the user's PATH alongside `duoduo` and pollute their Node resolution).

## Design (gated on duoduo#50)

This feature **only ships** for a duoduo version that implements [openduo/duoduo#50](https://github.com/openduo/duoduo/issues/50) — a `DUODUO_NODE_BIN` environment variable that lets the wrapper bypass PATH-based node resolution. Older duoduo versions explicitly will **not** be supported; manager will surface a clear "requires duoduo ≥ vX.Y.Z" message instead of attempting any wrapper-overwrite or symlink-based workaround.

Rationale: a wrapper-overwrite workaround would have to (a) replace the npm-installed wrapper with a manager-generated absolute-path launcher, (b) re-replace it after every `npm install -g @openduo/duoduo` upgrade, and (c) handle `.app` relocation. That is real surface area, real bugs, real upgrade-window race conditions. Waiting for upstream to expose `DUODUO_NODE_BIN` collapses all of that into "set one env var."

### Manager-side implementation (post-duoduo#50)

1. **Daemon env**: when starting the daemon (and any duoduo-spawned subprocess we control), export `DUODUO_NODE_BIN=<abs path to bundled node>`. This lets the wrapper resolve `node` without PATH.
2. **Shell PATH inject**: append a marked block to `~/.zshrc` / `~/.bash_profile`:

   ```sh
   # >>> duoduo-manager (managed) >>>
   [ -d "$HOME/.duoduo-manager/bin" ] && export PATH="$HOME/.duoduo-manager/bin:$PATH"
   # <<< duoduo-manager (managed) <<<
   ```

   The directory check makes the export a no-op if the user removes the manager directory — no stale-PATH pollution.

3. **Onboarding step**: a visible "Add to shell PATH" panel that explains exactly what file is touched and what line is added, with an Undo control.

4. **No node/npm symlinks** in `~/.duoduo-manager/bin/`. The user's `node` / `npm` resolution remains entirely untouched. This is the key non-pollution property and it's what `DUODUO_NODE_BIN` buys us.

5. **Version gate**: detect installed duoduo version via the existing channel-status / package.json read path. If below the minimum, the onboarding step is disabled with a clear "upgrade duoduo to enable" message.

### Out of scope

- Changes to where duoduo is installed (still `npm install -g @openduo/duoduo` into `~/.duoduo-manager`).
- Any sudo-requiring system-wide installer (e.g. `/usr/local/bin/duoduo` symlink, `/etc/paths.d/` entry).
- Any wrapper-overwrite or upgrade-hook workaround for older duoduo versions.
- LaunchAgent / daemon-startup mechanism changes (this feature is about subprocess PATH, not how the daemon itself is brought up).

## Files likely to touch (post-duoduo#50)

- `Sources/Services/NodeRuntime.swift` — expose absolute path to bundled node for `DUODUO_NODE_BIN`.
- `Sources/Services/DaemonService.swift` — inject `DUODUO_NODE_BIN` into daemon env on start/restart.
- `Sources/Services/ChannelService.swift` — same env injection for channel start.
- New: `Sources/Services/ShellPathInstaller.swift` — manage the `~/.zshrc` / `~/.bash_profile` block (install / detect / uninstall).
- `Sources/Views/Onboarding/` — add the PATH-setup step + version gate.
- Localization: new strings under `Sources/Resources/{en,zh-Hans}.lproj/Localizable.strings`.

## Status

- [x] Branch `feat/expose-duoduo-in-path` created from `main`
- [x] Root cause verified on a real bundled install
- [x] Upstream issue filed: [openduo/duoduo#50](https://github.com/openduo/duoduo/issues/50)
- [ ] Upstream `DUODUO_NODE_BIN` shipped in a tagged duoduo release
- [ ] Manager implementation (per "Manager-side implementation" above)
- [ ] Manual verification on a fresh bundled install: from inside a `claude` Bash tool run, `duoduo --help` works
- [ ] PR ready for merge

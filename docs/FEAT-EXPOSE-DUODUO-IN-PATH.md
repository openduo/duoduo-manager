# Feature: Expose `duoduo` to agent subprocess shells (all-in-one mode)

> Working notes for branch `feat/expose-duoduo-in-path`. Implementation gated on duoduo ≥ `0.5.0-rc.1`, the first tagged release whose `bin/duoduo` wrapper honors `DUODUO_NODE_BIN` (upstream change merged via [openduo/duoduo#50](https://github.com/openduo/duoduo/issues/50)).

## Goal

In bundled (`*-with-nodejs`) installs of DuoduoManager, agent subprocesses spawned by the duoduo daemon — including `bash -lc "duoduo …"` invoked from inside agent tool runs — must be able to resolve and execute the `duoduo` CLI.

## Symptom (verified on a real install)

Verified on a real bundled install (`arm64-with-nodejs`, duoduo `0.4.6`):

- The duoduo daemon process (spawned via the `duoduo daemon start` CLI) inherits a PATH that includes `~/.duoduo-manager/bin` and the bundled `…/node/bin`. Inside the daemon, `duoduo` is resolvable.
- Daemon-spawned children (e.g. the `claude` agent runner) also fully inherit that PATH.
- **But** any further `bash -lc "…"` / `zsh -lc "…"` invoked from those children re-runs the shell's *login*-shell startup files (for bash: `/etc/profile` plus the first existing of `~/.bash_profile` / `~/.bash_login` / `~/.profile`; for zsh: `/etc/zprofile` plus `~/.zprofile`). `~/.zshrc` is **not** sourced — it is interactive-only. These login-shell startup files **completely replace** the inherited PATH with the user's login PATH. That PATH never contains `~/.duoduo-manager/bin` (it's a manager-private prefix the user's shell doesn't know about) nor the `.app`-bundled `node/bin`.
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

## Design (relies on duoduo ≥ 0.5.0)

This feature relies on the upstream `bin/duoduo` wrapper honoring the `DUODUO_NODE_BIN` env var. That landed in the duoduo `0.5.0` series (PR for [openduo/duoduo#50](https://github.com/openduo/duoduo/issues/50) merged at `0.5.0-pre.22`). Older duoduo versions explicitly will **not** support this manager feature; manager surfaces a clear "requires duoduo ≥ 0.5.0" message instead of attempting any wrapper-overwrite or symlink-based workaround.

Rationale: a wrapper-overwrite workaround would have to (a) replace the npm-installed wrapper with a manager-generated absolute-path launcher, (b) re-replace it after every `npm install -g @openduo/duoduo` upgrade, and (c) handle `.app` relocation. That is real surface area, real bugs, real upgrade-window race conditions. The `DUODUO_NODE_BIN` upstream entrypoint collapses all of that into "set one env var."

### Manager-side implementation

1. **Single source of truth** — `Sources/Services/DuoduoCompat.swift` holds the env var name and `minVersionForNodeBinEnv`. All gating reads from this file; bumping the minimum version is a one-line change.

2. **Daemon and channel env** — `NodeRuntime.duoduoSpawnEnv` returns `[DUODUO_NODE_BIN: <abs path to bundled node>]` whenever a bundled node exists. `DaemonService.daemonEnv` and `ChannelService.env` merge it in. Older wrappers ignore the variable, so the injection is always backward-safe — but only on a wrapper that honors it does the value actually take effect.

3. **Shell PATH inject** — `Sources/Services/ShellPathInstaller.swift` writes a marked block into `~/.zprofile` and `~/.bash_profile` (the login-shell startup files; `~/.zshrc` is interactive-only and would not be read by daemon-spawned `zsh -lc` invocations):

   ```sh
   # >>> duoduo-manager (managed) >>>
   if [ -d "$HOME/.duoduo-manager/bin" ]; then
       export PATH="$HOME/.duoduo-manager/bin:$PATH"
   fi
   # <<< duoduo-manager (managed) <<<
   ```

   The directory check makes the export a no-op if the user removes the manager directory — no stale PATH entry. The installer is idempotent (re-install replaces the block in place) and provides explicit `uninstall`.

4. **Onboarding panel** — `AgentShellPathPanel` (in `OnboardingView.swift`) appears in the completion view and shows the current state pill (Enabled / Not enabled / Partially installed) with Enable / Refresh / Remove actions. Below the gate (no duoduo installed, or duoduo < 0.5.0), the action row is replaced with a "requires duoduo ≥ 0.5.0" message — no destructive action is available until the gate clears.

5. **No node/npm symlinks** in `~/.duoduo-manager/bin/`. The user's `node` / `npm` resolution remains entirely untouched. This is the key non-pollution property and is exactly what `DUODUO_NODE_BIN` buys us — the wrapper finds node via the env var, so we don't have to inject node into PATH alongside duoduo.

### Out of scope (deferred)

- Status bar popover or Settings entry for the PATH installer (currently only reachable through the Onboarding completion view).
- Changes to where duoduo is installed (still `npm install -g @openduo/duoduo` into `~/.duoduo-manager`).
- Any sudo-requiring system-wide installer (e.g. `/usr/local/bin/duoduo` symlink, `/etc/paths.d/` entry).
- Any wrapper-overwrite or upgrade-hook workaround for older duoduo versions.
- LaunchAgent / daemon-startup mechanism changes (this feature is about subprocess PATH, not how the daemon itself is brought up).

## Files touched

- `Sources/Services/DuoduoCompat.swift` (new) — env var name + min version constants.
- `Sources/Services/NodeRuntime.swift` — `duoduoSpawnEnv` computed property.
- `Sources/Services/DaemonService.swift` — merge `duoduoSpawnEnv` into `daemonEnv`.
- `Sources/Services/ChannelService.swift` — same merge in channel `env`.
- `Sources/Services/ShellPathInstaller.swift` (new) — marked-block install / detect / uninstall.
- `Sources/Views/Onboarding/OnboardingView.swift` — `AgentShellPathPanel` in the completion view.
- `Sources/Localization/L10n.swift` + `Sources/Resources/{en,zh-Hans}.lproj/Localizable.strings` — `Onboard.ShellPath.*` strings.

## Status

- [x] Branch `feat/expose-duoduo-in-path` created from `main`
- [x] Root cause verified on a real bundled install
- [x] Upstream issue filed: [openduo/duoduo#50](https://github.com/openduo/duoduo/issues/50)
- [x] Upstream `DUODUO_NODE_BIN` merged (in `0.5.0-pre.22`); awaiting tagged `0.5.0` release
- [x] Manager implementation
- [ ] End-to-end verification on a fresh bundled install with duoduo ≥ 0.5.0: from inside a `claude` Bash tool run, `duoduo --help` works
- [ ] Un-draft PR after upstream tags `v0.5.0`

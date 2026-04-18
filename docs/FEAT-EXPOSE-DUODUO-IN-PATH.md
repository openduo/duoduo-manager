# Feature: Expose `duoduo` CLI on Daemon's PATH

> Working notes for branch `feat/expose-duoduo-in-path`. Drafted before implementation — to be refined as the user provides full context.

## Goal

When DuoduoManager launches the daemon (and its child processes), the `duoduo` CLI must be reachable via `PATH`. This way the daemon, its agent sessions, and any spawned shell (e.g. `claude-code`, `bash -c "duoduo …"`) can invoke `duoduo` by name without absolute paths.

## Why this matters

- The daemon is currently launched by **launchd** via the LaunchAgent plist (`ai.openduo.manager.daemon`). launchd does **not** inherit the user's interactive shell environment — only what the plist's `EnvironmentVariables` block declares.
- Subprocesses of the daemon (sessions, tool runs) inherit launchd's environment. If `duoduo` isn't on PATH there, anything that shells out to `duoduo …` breaks even though the binary exists at `~/.duoduo-manager/bin/duoduo`.
- See `docs/LAUNCHD-MIGRATION.md` for the TCC/FDA reasoning behind the LaunchAgent move; this feature is the natural follow-up: now that launchd owns the daemon, we must make sure the daemon's PATH is correct *by construction*, not by accident.

## Current state (pre-change, to verify)

- `NodeRuntime.environment` builds PATH as: bundled `node/bin` → `~/.duoduo-manager/bin` (npm global bin) → merged current PATH + login-shell PATH.
- `LaunchAgentService.install(environment:)` writes `EnvironmentVariables` into the plist from a dict that includes `PATH` and `NPM_CONFIG_PREFIX`.
- Open question: does the PATH the plist receives currently include `~/.duoduo-manager/bin`? If yes, the symptom must be elsewhere (symlink target missing, npm global moved, etc.). If no, we need to inject it.

## Open questions for the user

1. Is the symptom "duoduo: command not found" inside an agent session, or something more specific?
2. Should `duoduo` be exposed via:
   - **(a)** an explicit PATH entry pointing at `~/.duoduo-manager/bin` in the LaunchAgent plist, or
   - **(b)** a stable symlink under `/usr/local/bin` / `~/.local/bin`, or
   - **(c)** an env var like `DUODUO_BIN` instead of relying on PATH?
3. Should this also apply to channel processes (`duoduo channel feishu start`), or daemon-only?
4. Any constraints on existing user installs (some users may already have `~/.duoduo-manager/bin` on PATH from a prior version)?

## Files likely to touch

- `Sources/Services/NodeRuntime.swift` — PATH/env composition
- `Sources/Services/LaunchAgentService.swift` — plist `EnvironmentVariables`
- `Sources/Services/DaemonService.swift` — if start/restart needs to repush env
- Possibly `Sources/Services/ChannelService.swift` if channels are in scope

## Out of scope (until confirmed)

- Changing where duoduo gets installed (still `npm install -g @openduo/duoduo` into `~/.duoduo-manager`).
- Adding a system-wide installer.
- Migrating away from LaunchAgent.

## Status

- [x] Branch `feat/expose-duoduo-in-path` created from `main`
- [x] Feature notes drafted (this file)
- [ ] Awaiting full requirements from user
- [ ] Implementation
- [ ] Manual verification: confirm `duoduo` resolvable from a daemon-spawned bash
- [ ] PR

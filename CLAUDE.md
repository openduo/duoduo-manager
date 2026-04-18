# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

DuoduoManager is a macOS 14+ menu bar app (SwiftUI + AppKit) that controls the [duoduo](https://github.com/openduo/duoduo) Node.js daemon and exposes an ATC Dashboard, CC Reader, and an Onboarding flow. The Xcode project is generated from `project.yml` via XcodeGen — never edit `DuoduoManager.xcodeproj` by hand. There is no `Package.swift`; SwiftPM is not used.

## Common commands

```bash
make project         # Regenerate DuoduoManager.xcodeproj from project.yml (run after editing project.yml)
make build           # Debug build via xcodebuild
make run             # Build + launch in Debug, forces system Node.js + universal-lite variant for dev
make run-release     # Release build + launch
make clean           # Remove .build/ and dist/

make app             # 3 .app bundles (arm64-with-nodejs, x86_64-with-nodejs, universal-lite) via build_app.sh
make dmg             # 3 DMGs from existing app bundles
make publish         # Full release: build + sign + DMG + notarize (requires .secret.env or env vars)

make version                        # Print MARKETING_VERSION from project.yml
make update-version NEW_VERSION=x.y.z  # Bump version, commit, tag vX.Y.Z, push main+tags (CI builds release)
```

There is no test target in this project — do not invent test commands.

`make run` patches the built Info.plist with `DuoduoNodeRuntimeMode=system` and `DuoduoBuildVariant=universal-lite` so dev runs use the system Node.js without bundling.

## Architecture (read before editing across layers)

Layered root-store architecture: `Host -> Views -> Presentations -> Stores -> Services -> Models`. The full design rationale lives in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — read it before reorganizing layers, adding new stores, or changing polling cadence.

Key invariants:

- **`AppStore` is the single root store** and orchestration boundary. It owns surface visibility (popover/dashboard), polling task lifecycles, service instances, and composes four domain stores: `RuntimeStore`, `DashboardStore`, `UpdateStore`, `CommandStore`. Do not introduce parallel view models for runtime/dashboard/update state — both the popover and ATC Dashboard must read from the same store to avoid stale caches.
- **Visibility-driven polling.** No background polling at launch. Polling for runtime/update/dashboard starts only when the popover or dashboard surface becomes visible, and stops once no visible surface still needs the data. Hooks are `AppStore.setPopoverVisible` / `setDashboardVisible`, wired from `AppStatusController` / `AppWindowController` in `DuoduoManagerApp.swift`.
- **Presentation mappers shape data for views.** SwiftUI views never reach into raw store data — go through `StatusBarPresentationMapper`, `DashboardPresentationMapper`, or `SharedPresentationFormatting`.
- **`@Observable` (Swift 5.9, macOS 14+)** is used for stores. Don't reintroduce `ObservableObject`/`@Published`.
- **Mixed AppKit + SwiftUI.** AppKit owns menu bar primitives (`NSStatusItem`, `NSPopover`, `NSPanel`, activation policy) in `Host/`. SwiftUI handles all content under `Views/{StatusBar,Dashboard,Config,Onboarding,Shared}`.

## Runtime / Node.js model

The app does not embed daemon logic — it shells out to the `duoduo` CLI and talks JSON-RPC to its HTTP endpoint. `NodeRuntime` is the single source of truth for subprocess environments because menu bar apps don't inherit a terminal shell:

- Bundled Node lives at `.app/Contents/Resources/node/` (per-arch). Universal-lite builds omit it and require system Node.js 22+.
- Global npm prefix is `~/.duoduo-manager` (writable, persists across app upgrades). `duoduo` binary is `~/.duoduo-manager/bin/duoduo`.
- `NodeRuntime.environment` builds `PATH` as: bundled `node/bin` → npm global `bin` → merged current PATH + login-shell PATH (`$SHELL -l -c "echo $PATH"`).
- duoduo's global config is `~/.config/duoduo/config.json`; channel plugins live in `~/.aladuo/`.
- If `duoduo` is missing on first interactive surface, `AppStore.ensureDuoduoInstalledIfNeeded()` runs `npm install -g @openduo/duoduo`.

### Daemon lifecycle (LaunchAgent, not detached subprocess)

The daemon is managed by a macOS **LaunchAgent** (`ai.openduo.manager.daemon` under `~/Library/LaunchAgents/`), not by `duoduo daemon start`. This is a deliberate fix for macOS TCC/FDA breakage — a detached daemon (PPID=1) cannot inherit the app's TCC authorization, causing repeated permission prompts. Read [docs/LAUNCHD-MIGRATION.md](docs/LAUNCHD-MIGRATION.md) before touching `DaemonService` or `LaunchAgentService`. Channel lifecycle (e.g. Feishu) still goes through `duoduo channel <type> start|stop`.

Status checks still hit `/healthz` and `/rpc` over HTTP — they are independent of how the daemon was started.

### Polling cadence (defined in stores, not views)

- Dashboard events: 3s · Dashboard status/usage/jobs: 5s · Runtime refresh: 30s (popover only) · App update check: 10 min (popover only)
- Event buffer capped at 2000 entries in memory.

## Build variants and packaging

`build_app.sh` produces three variants — names are load-bearing because **Sparkle uses the variant string as its update channel** (see `SPUUpdaterDelegate.allowedChannels` in `DuoduoManagerApp.swift` and the appcast generation in `.github/workflows/release.yml`):

| Variant | `DuoduoBuildVariant` | `DuoduoNodeRuntimeMode` | Bundled Node |
|---|---|---|---|
| `arm64-with-nodejs` | `arm64-with-nodejs` | `bundled` | yes |
| `x86_64-with-nodejs` | `x86_64-with-nodejs` | `bundled` | yes |
| `universal-lite` | `universal-lite` | `system` | no (lipo'd binary, system Node 22+) |

Both Info.plist keys are written by `build_app.sh` per variant. If you add a new variant, you must also update the appcast generation block in `.github/workflows/release.yml`.

## Release flow

The normal path is `make update-version NEW_VERSION=x.y.z` → push `main` + tag → GitHub Actions runs `make publish` (sign + notarize + DMG) → uploads DMGs to the GitHub Release → signs each DMG with the Sparkle EdDSA private key → generates `appcast.xml` → commits to the `gh-pages` branch (served at `https://openduo.github.io/duoduo-manager/appcast.xml`).

Local `make publish` requires `.secret.env` with `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD`, `APPLE_TEAM_ID`, `APPLE_SIGNING_IDENTITY`, and optionally `SPARKLE_PUBLIC_ED_KEY` (template in `secret.env.example`). CI uses repo secrets instead.

The release workflow also fires on `repository_dispatch: cc-reader-released` to produce a prerelease sync build when the upstream cc-reader package ships a new version.

## Localization

English (`en`) and Simplified Chinese (`zh-Hans`) under `Sources/Resources/{en,zh-Hans}.lproj/`. All strings go through `L10n.swift` (typed nested enums) — never hardcode user-facing text in views. Adding a new key requires updating both `.strings` files **and** `L10n.swift`. Full guide in [docs/I18N.md](docs/I18N.md).

## Conventions worth knowing

- `entitlements.mac.plist` controls codesign entitlements; `Config/Info.plist` is the canonical Info.plist (referenced from `project.yml`, not generated).
- `cc-reader` is consumed as a SwiftPM package (`CCReaderKit`) declared in `project.yml`; the CC Reader window is a SwiftUI scene defined in `DuoduoManagerApp.swift`.
- Sparkle is integrated via `SPUStandardUpdaterController` in `AppDelegate`; the per-variant channel filtering in `allowedChannels` is what keeps an arm64 build from offering an x86_64 update.
- Do not commit `.secret.env`, `*.p12`, `*.cer`, or `dist/` artifacts.

## Contribution & Commit SOP

This is a public repository. All changes — yours and the user's — flow through pull requests against `main`. Direct pushes to `main` are reserved for `make update-version` (version bump + tag).

### Branch & PR flow

1. **Branch from `main`** with a focused name: `feat/<slug>`, `fix/<slug>`, `docs/<slug>`, `chore/<slug>`. One feature/fix per branch.
2. **Confirm with the user before pushing** — `git push` to a public branch is visible immediately. The user's standing rule is to confirm before every push, even if a previous push was approved.
3. **Open the PR with `gh pr create --base main`**. PR title uses the same Conventional Commits prefix as the lead commit. Body should describe user-visible behavior and any public-API touchpoints, not internal implementation walkthroughs.
4. **Never push to `main` directly** for feature work. Even trivial doc edits go through a PR so review history stays linear.

### Commit message format

Use Conventional Commits:

- `feat: <what the user gets>`
- `fix: <user-visible bug>`
- `docs: <doc area>`
- `chore: <housekeeping>`
- `refactor: <internal restructure with no behavior change>`
- `i18n: <localization changes>`

Append the project co-author trailer to every commit:

```bash
git commit -m "feat: short summary

Optional body explaining the why and any user-visible impact." \
  --trailer "Co-authored-by: Duoduo <noreply@openduo.ai>"
```

Do **not** add a `Co-Authored-By: Claude …` trailer in this repo — the project trailer above is the only one used here.

### What never goes into a public commit, PR, or issue

- Internal source paths, internal package names, or internal symbol names from any non-public upstream — describe behavior at the public CLI / JSON-RPC / npm-package level instead.
- Pasted source from any non-public repo. If you read non-public reference material to understand behavior, re-derive descriptions from the public surface (`@openduo/duoduo` CLI, RPC methods, exported types).
- Secrets: signing keys, Apple IDs, app-specific passwords, Sparkle private keys, GitHub PATs. Use environment variables or `.secret.env` (gitignored).
- Local-only context files (e.g. `CLAUDE.local.md`).

### Issue & cross-repo coordination

- Bugs and user-facing issues for this app belong on `openduo/duoduo-manager`. Use `gh issue --repo openduo/duoduo-manager …`.
- If a feature in this repo needs a change in the runtime, file an issue on `openduo/duoduo` describing the desired **public** behavior (CLI flag, RPC method, env var contract) — not the internal change needed to deliver it.
- Reproductions: small reproducer commits live in this repo on a branch; the linked issue describes the scenario and conclusion only.

### Pre-push self-check

Before `git push` or `gh pr create`, mentally run through:

1. Does the diff or message reference any non-public repo, internal path, or internal symbol? → strip it.
2. Does the diff include any secret or signing material? → strip it.
3. Is the commit prefix conventional and the co-author trailer present?
4. Has the user explicitly approved this push?

If any answer is no, stop and fix before pushing.

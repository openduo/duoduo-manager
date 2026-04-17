# Architecture

## Overview

DuoduoManager is a macOS menu bar app (SwiftUI + AppKit) for controlling duoduo runtime components and exposing two desktop tools:

- **Status popover** for daemon/channel operations and upgrades
- **ATC Dashboard panel** for real-time session/job/event monitoring
- **CC Reader window** for browsing Claude Code histories via `CCReaderKit`

The app now follows a layered root-store architecture:

```
Host -> Views -> Presentations -> Stores -> Services -> Models
```

```
DuoduoManagerApp.swift
├── Host/
│   ├── AppStatusController.swift   (NSStatusItem + NSPopover host shell)
│   └── AppWindowController.swift   (Dashboard NSWindow lifecycle)
├── Stores/
│   ├── AppStore.swift              (root orchestration store)
│   ├── AppStore+Visibility.swift   (surface-driven polling lifecycle)
│   ├── AppStore+Actions.swift      (user actions / command entrypoints)
│   ├── AppStore+Fetch.swift        (runtime, update, dashboard fetch logic)
│   ├── RuntimeStore.swift
│   ├── DashboardStore.swift
│   ├── UpdateStore.swift
│   └── CommandStore.swift
├── Presentations/
│   ├── StatusBarPresentation.swift
│   ├── StatusBarPresentationMapper.swift
│   ├── DashboardPresentation.swift
│   ├── DashboardPresentationMapper.swift
│   └── SharedPresentationFormatting.swift
├── Views/
│   ├── StatusBar/
│   ├── Dashboard/
│   ├── Config/
│   ├── Onboarding/
│   └── Shared/
├── Services/
│   ├── NodeRuntime.swift
│   ├── ShellService.swift
│   ├── DaemonService.swift
│   ├── ChannelService.swift
│   ├── DashboardRPCService.swift
│   ├── VersionService.swift
│   ├── UpgradeService.swift
│   ├── AppUpdateService.swift
│   ├── ClaudeAuthService.swift
│   └── OnboardingService.swift
├── Models/
│   ├── ConfigStore.swift
│   ├── DaemonConfig.swift
│   ├── FeishuConfig.swift
│   ├── DaemonStatus.swift
│   ├── ChannelInfo.swift
│   ├── ChannelRegistry.swift
│   ├── PackageVersion.swift
│   ├── DashboardModels.swift
│   └── OnboardingState.swift
└── Localization/
    └── L10n.swift
```

## Layer Responsibilities

### Host

The `Host` layer is the AppKit shell around the app:

- `AppStatusController` owns the menu bar item, popover presentation, and status icon updates
- `AppWindowController` owns the Dashboard window lifecycle. CC Reader uses a SwiftUI `WindowGroup`, and Onboarding uses `OnboardingWindowController`

`DuoduoManagerApp.swift` now acts mainly as the composition root that wires `Host` to `AppStore` and root SwiftUI views.

### Stores

`AppStore` is the root store and orchestration boundary. It owns:

- surface visibility state (`popover`, `dashboard`)
- polling task lifecycle
- service instances
- cross-domain coordination

It composes four domain stores:

- `RuntimeStore`
  daemon status, channel state, runtime config, bootstrap/install state
- `DashboardStore`
  sessions, jobs, subconscious, health, cadence, event stream, usage totals, system config
- `UpdateStore`
  latest runtime versions and app release information
- `CommandStore`
  current command output, loading state, and transient errors

This keeps domain state independent while preserving a single root orchestration point.

### Presentations

SwiftUI views do not directly shape raw store data into UI structures. That responsibility lives in:

- `StatusBarPresentationMapper`
- `DashboardPresentationMapper`
- `SharedPresentationFormatting`

These mappers produce concise display-oriented models for the popover and ATC Dashboard, and keep view files focused on composition and rendering.

### Views

Views are now grouped by feature instead of being flat:

- `Views/StatusBar` — popover UI
- `Views/Dashboard` — ATC dashboard panes
- `Views/Config` — daemon and channel inline config
- `Views/Onboarding` — first-time setup wizard
- `Views/Shared` — reusable components

The `StatusBar` feature is split into a root view plus section components. `Dashboard` contains the dashboard shell and its content panes. `Onboarding` provides a guided checklist for installing duoduo CLI, Claude CLI, connecting an LLM provider, and starting the daemon.

## Runtime Environment

### Node.js and npm strategy

- **Bundled Node.js runtime**: packaged under `.app/Contents/Resources/node/`, architecture-specific (arm64/x86_64 built separately)
- **Global npm prefix**: `~/.duoduo-manager` (`NodeRuntime.npmGlobalDir`) for writable persistence across app upgrades
- **duoduo binary path**: resolved via PATH (includes `~/.duoduo-manager/bin/duoduo`), `NodeRuntime.duoduoPath` returns bare `"duoduo"`
- **Subprocess env assembly**: `NodeRuntime.environment` builds `PATH` as:
  1) bundled `node/bin`
  2) npm global `bin`
  3) merged current PATH + login-shell PATH (`$SHELL -l -c "echo $PATH"`)
- **Install bootstrap**: if duoduo is missing, `AppStore.ensureDuoduoInstalledIfNeeded()` runs `npm install -g @openduo/duoduo` when an interactive surface is first shown

### Shared duoduo state

- **duoduo global config**: `~/.config/duoduo/config.json` (shared by all duoduo entrypoints)
- **channel plugin directory**: `~/.aladuo/` (managed by `duoduo channel install`)

### Daemon lifecycle

- **Start/stop/restart**: `DaemonService` executes `duoduo daemon <cmd>` with:
  - `ALADUO_DAEMON_URL`
  - `ALADUO_LOG_LEVEL=debug`
  - extra env from `DaemonConfig`
- **Working directory rule**: commands run in `NodeRuntime.duoduoPackageDir` (resolved from symlinked duoduo bin) to keep daemon relative-path assets resolvable
- **Status/version**:
  - running status via `duoduo daemon status`
  - installed version via local package `package.json`
- **Process model**: daemon is detached/background-managed by duoduo and can survive app quit

### Channel lifecycle

- **Registry**: `ChannelRegistry` is explicit (currently `feishu`)
- **Install/sync**: uses `duoduo channel install <package>`
- **Start/stop**: uses `duoduo channel <type> start|stop` with per-channel extra env (for Feishu from `FeishuConfig`)
- **Status**: parsed from `duoduo channel <type> status`

### Visibility-Driven Lifecycle

The app no longer does persistent background polling from startup.

- **On app launch**:
  - create host controllers
  - create `AppStore`
  - no runtime/dashboard/update fetch is started yet

- **When popover becomes visible**:
  - mark surface `.popover` visible
  - ensure duoduo is installed if needed
  - fetch runtime state
  - fetch update state
  - fetch dashboard status + events
  - start runtime/update/dashboard polling

- **When ATC Dashboard becomes visible**:
  - mark surface `.dashboard` visible
  - fetch dashboard status + events
  - start dashboard polling if not already active

- **When surfaces are hidden**:
  - polling stops automatically once no visible surface still needs that data

This means polling is now driven by UI visibility rather than by startup or duplicated per-view models.

### Dashboard Data Transport

`DashboardRPCService` calls daemon JSON-RPC endpoint `POST <daemonURL>/rpc`.

Polled methods:

- `system.status` for sessions, health, subconscious, cadence
- `usage.get` for token/cost/tool aggregates
- `job.list` for jobs
- `spine.tail` for incremental event stream with `after_id`

Polling cadence:

- dashboard events: every 3s
- dashboard status/usage/jobs: every 5s
- runtime refresh: every 30s while popover is visible
- update checks: every 10 min while popover is visible

Event retention is capped in memory at 2000 entries.

### App update lifecycle

- **Source**: GitHub Releases API (`/repos/openduo/duoduo-manager/releases/latest`)
- **Sparkle**: In-app updates via `SPUStandardUpdaterController` with channel-based rollouts per build variant (`DuoduoBuildVariant`)
- **State**: `UpdateStore.appLatestVersion` + `appLatestReleaseURL`
- **UI signal**: status bar header shows a "New v{x.x.x}" badge when a newer app version exists

### Onboarding flow

The onboarding system uses a reducer pattern (`OnboardingEvent` → `OnboardingReducer` → `OnboardingCommand`) with an `@Observable` `OnboardingStore`:

- `OnboardingService.detect()` — checks duoduo CLI, Claude CLI, `claude auth status`, and daemon health
- `ClaudeCLIService` — installs Claude CLI, runs OAuth login, reads auth status
- `ClaudeSettingsStore` — reads and writes `~/.claude/settings.json` with format-preserving JSON merge
- `LLMProviderPreset` — predefined configurations for Official (Anthropic OAuth), 智谱 GLM, Z.AI, Kimi, 百炼, MiniMax, DeepSeek, and custom endpoints

The flow auto-advances through install steps and presents the LLM provider configuration (token/base URL or browser login) before starting the daemon. Accessible from the popover footer or automatically on first launch.

## Key Design Decisions

### Why a root store instead of separate view models?

The status popover and ATC dashboard both need overlapping runtime, dashboard, and update state. A shared root store prevents:

- duplicated polling
- stale parallel caches
- popover/dashboard disagreement about the current runtime state

Domain stores keep the state model readable, while `AppStore` keeps orchestration centralized.

### Why `@Observable` (macOS 14+)?

The project targets modern Swift observation to reduce boilerplate and avoid `ObservableObject` + `@Published` ceremony.

### Why `NodeRuntime` as a dedicated service?

A menu bar app does not reliably inherit terminal shell environment. Centralizing PATH/NPM/NODE setup in `NodeRuntime` ensures all subprocesses behave the same regardless of launch context.

### Why direct CLI + JSON-RPC instead of embedded daemon logic?

duoduo remains the single source of truth for process lifecycle and event/state APIs. The app acts as a control/monitoring client, reducing duplicated runtime logic.

### Why keep channel registry explicit?

Static registration (`ChannelRegistry`) gives predictable UI behavior, localized labels/icons, and controlled env mapping without runtime plugin discovery complexity.

### Why `.strings` over `.xcstrings`?

The project builds with SwiftPM (`swift build`). `.lproj/Localizable.strings` works in both SPM runtime and packaged `.app` without Xcode-only catalog tooling.

### Why mixed AppKit + SwiftUI?

- AppKit handles menu bar primitives (`NSStatusItem`, `NSPopover`, `NSPanel`, activation policy).
- SwiftUI handles all content rendering and state binding.

This hybrid model keeps native menu bar behavior while preserving SwiftUI development ergonomics.

### Why feature-grouped views?

The project previously had a flatter `Views/` layout and generic directories like `Content/`. Views are now grouped by feature so that status bar, dashboard, config, and shared UI evolve independently and are easier to navigate.

## Build and Packaging

`build_app.sh` drives release artifacts:

1. Detect latest Node.js 24 LTS patch and cache arm64/x64 tarballs in `.node-cache`
2. Build separate Swift binaries for `arm64` and `x86_64`
3. Assemble a standard `.app` bundle from `Config/Info.plist` and bundled resources
4. Copy localized `.lproj` resources into app bundle
5. Extract matching-arch Node runtime into `Contents/Resources/node` (tar-based to preserve symlinks)
6. Optional signing/notarization (if `.secret.env` exists)
7. Generate per-variant DMGs:
   - `DuoduoManager-{version}-arm64-with-nodejs.dmg`
   - `DuoduoManager-{version}-x86_64-with-nodejs.dmg`
   - `DuoduoManager-{version}-universal-lite.dmg`

For repository releases, the normal workflow is:

1. `make update-version NEW_VERSION=x.y.z`
2. push `main` and tag `vX.Y.Z`
3. let GitHub Actions build and publish release artifacts

# Architecture

## Overview

DuoduoManager is a macOS menu bar app (SwiftUI + AppKit) for controlling duoduo runtime components and exposing two desktop tools:

- **Status popover** for daemon/channel operations and upgrades
- **ATC Dashboard panel** for real-time session/job/event monitoring
- **CC Reader window** for browsing Claude Code histories via `CCReaderKit`

The app follows a layered MVVM-style architecture:

```
Views -> ViewModels -> Services -> Models
```

```
DuoduoManagerApp.swift (entry point + NSStatusItem/NSPopover lifecycle)
├── StatusBarView.swift          (menu bar popover)
│   ├── DaemonConfigView.swift   (daemon config panel)
│   ├── FeishuConfigView.swift   (channel config panel)
│   └── ConfigLayout.swift       (shared form rows)
├── DashboardView.swift          (ATC Dashboard panel root)
│   ├── Content/EventsContentView.swift
│   ├── Content/SessionsContentView.swift
│   ├── Content/JobsContentView.swift
│   └── EventStreamView.swift
├── ViewModels/
│   ├── DaemonViewModel.swift    (popover orchestration + update logic)
│   └── DashboardViewModel.swift (RPC polling + aggregated metrics)
├── Services/
│   ├── NodeRuntime.swift        (runtime paths/env/bootstrap install)
│   ├── ShellService.swift       (subprocess execution + debug logging)
│   ├── DaemonService.swift      (duoduo daemon CLI wrapper)
│   ├── ChannelService.swift     (duoduo channel CLI wrapper)
│   ├── DashboardRPCService.swift(JSON-RPC client: /rpc)
│   ├── VersionService.swift     (npm latest version lookup)
│   ├── UpgradeService.swift     (version-aware upgrade orchestration)
│   └── AppUpdateService.swift   (GitHub release check for app updates)
├── Models/
│   ├── ConfigStore.swift
│   ├── DaemonConfig.swift
│   ├── FeishuConfig.swift
│   ├── DaemonStatus.swift
│   ├── ChannelInfo.swift
│   ├── ChannelRegistry.swift
│   ├── PackageVersion.swift
│   └── DashboardModels.swift    (JSON-RPC response models)
└── Localization/
    └── L10n.swift
```

## Runtime Environment

### Node.js and npm strategy

- **Bundled Node.js runtime**: packaged under `.app/Contents/Resources/node/`, architecture-specific (arm64/x86_64 built separately)
- **Global npm prefix**: `~/.duoduo-manager` (`NodeRuntime.npmGlobalDir`) for writable persistence across app upgrades
- **duoduo binary path**: `~/.duoduo-manager/bin/duoduo` (`NodeRuntime.duoduoPath`)
- **Subprocess env assembly**: `NodeRuntime.environment` builds `PATH` as:
  1) bundled `node/bin`
  2) npm global `bin`
  3) merged current PATH + login-shell PATH (`$SHELL -l -c "echo $PATH"`)
- **Install bootstrap**: if duoduo is missing, `DaemonViewModel.ensureDuoduoInstalled()` runs `npm install -g @openduo/duoduo` automatically

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

### ATC Dashboard lifecycle

- **Window creation**: launched from popover footer ("ATC"), hosted in `NSPanel`
- **Data transport**: `DashboardRPCService` calls daemon JSON-RPC endpoint `POST <daemonURL>/rpc`
- **Polled methods**:
  - `system.status` (sessions, health, subconscious, cadence)
  - `usage.get` (token/cost/tool aggregates)
  - `job.list` (jobs + run state)
  - `spine.tail` (incremental event stream with `after_id`)
- **Polling cadence (`DashboardViewModel`)**:
  - events: every 3s
  - status/usage/jobs: every 5s
- **Event retention**: in-memory cap at 2000 entries

### App update lifecycle

- **Source**: GitHub Releases API (`/repos/openduo/duoduo-manager/releases/latest`)
- **State**: `DaemonViewModel.appLatestVersion` + `appLatestReleaseURL`
- **UI signal**: status bar icon switches to update badge when a newer app version exists

## State Flows

`DaemonViewModel` intentionally separates two flows:

1. **Runtime refresh (`refreshStatus`)**
   - daemon running state / pid / installed version
   - installed channel list + per-channel runtime state
   - fast local operations, called after command execution

2. **Update refresh (`checkForUpdates`)**
   - npm latest version for daemon/channels
   - latest app release from GitHub
   - slower network operations, called on periodic refresh start and manual check

This separation keeps operational actions responsive while still exposing update information in the header.

## Key Design Decisions

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

## Build and Packaging

`build_app.sh` drives release artifacts:

1. Detect latest Node.js 24 LTS patch and cache arm64/x64 tarballs in `.node-cache`
2. Build separate Swift binaries for `arm64` and `x86_64`
3. Assemble `.app` from `DuoduoManager.app-template`
4. Copy localized `.lproj` resources into app bundle
5. Extract matching-arch Node runtime into `Contents/Resources/node` (tar-based to preserve symlinks)
6. Optional signing/notarization (if `.secret.env` exists)
7. Generate per-arch DMGs:
   - `DuoduoManager-{version}-arm64.dmg`
   - `DuoduoManager-{version}-x86_64.dmg`

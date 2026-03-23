# Architecture

## Overview

DuoduoManager follows a standard SwiftUI MVVM pattern:

```
Views → ViewModels → Services → Models
```

```
DuoduoManagerApp.swift (entry point, menu bar lifecycle)
├── StatusBarView.swift        (popover UI)
│   ├── DaemonConfigView.swift (daemon settings panel)
│   ├── FeishuConfigView.swift (Feishu channel settings panel)
│   └── ConfigLayout.swift     (shared config row components)
├── DaemonViewModel.swift      (single @Observable view model)
├── Services/
│   ├── ShellService.swift     (process execution, PATH loading)
│   ├── DaemonService.swift    (duoduo daemon CLI wrapper)
│   ├── ChannelService.swift   (duoduo channel CLI wrapper)
│   ├── UpgradeService.swift   (npm update orchestration)
│   └── VersionService.swift   (GitHub/npm version queries)
├── Models/
│   ├── ConfigStore.swift      (shared JSON persistence via UserDefaults)
│   ├── DaemonConfig.swift     (daemon settings + env var mapping)
│   ├── DaemonStatus.swift     (runtime status: running, version, pid)
│   ├── FeishuConfig.swift     (Feishu channel settings + env var mapping)
│   ├── ChannelInfo.swift      (installed channel runtime info: type, version, pid, running)
│   ├── ChannelRegistry.swift  (channel type registry)
│   └── PackageVersion.swift   (npm package version info)
└── Localization/
    └── L10n.swift             (type-safe localization keys)
```

## Runtime Environment

### Node.js and npm

- **Bundled Node.js**: The app bundles a full Node.js runtime in `.app/Contents/Resources/node/` (matching the app's architecture: arm64 or x86_64, built separately, no universal binary)
- **npm global packages**: Installed to `~/.duoduo-manager/` via `NPM_CONFIG_PREFIX`. This directory persists across app updates. The path must not contain spaces — duoduo's ESM self-invocation guard (`import.meta.url === file://${process.argv[1]}`) breaks when paths contain spaces because `import.meta.url` URL-encodes them but raw `process.argv[1]` does not
- **Subprocess environment**: `ShellService.run()` sets `PATH` (bundled node bin → npm-global bin → system PATH), `NPM_CONFIG_PREFIX`, and `NODE_PATH` for every child process

### Shared duoduo configuration

- **Global config**: `~/.config/duoduo/config.json` — shared by all duoduo instances (bundled, homebrew, CLI). Contains `daemonUrl`, `workDir`, etc.
- **Plugin directory**: `~/.aladuo/` — channel plugins are installed here by `duoduo channel install`, shared across all duoduo instances

### Daemon lifecycle

- **Startup**: App calls `ShellService.run()` to execute `~/.duoduo-manager/bin/duoduo daemon start` with `ALADUO_DAEMON_URL`, `ALADUO_LOG_LEVEL`, and user-defined config (port, workDir, etc.)
- **Daemon process**: duoduo CLI forks a detached background process running `daemon.js`. Parent process is PID 1 (launchd). The daemon **survives app exit**
- **Status**: `duoduo daemon status` queries the daemon via HTTP
- **Version**: Read directly from `~/.duoduo-manager/lib/node_modules/@openduo/duoduo/package.json` `version` field

### Channel lifecycle

- **Registration**: `ChannelRegistry` defines supported channel types (currently: feishu). This is hardcoded, not discovered
- **Status**: `duoduo channel <type> status` checks the shared plugin directory `~/.aladuo/`
- **Start/Stop**: `duoduo channel <type> start/stop` sends commands to the daemon; the daemon spawns/manages channel processes using its inherited PATH (bundled node)
- **Install**: `duoduo channel install <package>` fetches from npm registry and installs to `~/.aladuo/` — no separate `npm install -g` needed

### Update checking

- **Latest versions**: `npm view <package> version` (queries npm registry, network request)
- **Installed versions**: daemon version from local `package.json`; channel versions parsed from `duoduo channel <type> status` output
- **Timing**: Checked on popover open and periodically; status refreshes every 30s but does not re-check for updates

### Upgrade flow (upgradeAll)

Only performs actions for components that actually have newer versions available:

| daemon update? | channel update? | Actions |
|---|---|---|
| No | No | Nothing |
| Yes | No | `npm install -g @openduo/duoduo@latest` → restart daemon |
| No | Yes | Stop updated channels → `duoduo channel install` → restart channels |
| Yes | Yes | Stop updated channels → update + restart daemon → sync + restart channels |

## Key Decisions

### Why `@Observable` instead of `ObservableObject`?

The app targets macOS 14+ and uses Swift 5.9's `@Observable` macro for simpler, more performant observation without `@Published` property wrappers.

### Why manual shell sourcing in `ShellService`?

macOS GUI apps do not inherit the user's shell profile (`.zshrc`, `.zprofile`). Tools like `nvm`, `fnm`, or custom PATH entries would be missing. `ShellService.runShell()` explicitly sources these files before executing commands.

### Why no external dependencies?

The app uses only Foundation and SwiftUI from the standard library. No SPM packages are needed — all functionality is achieved through shell command execution and macOS system APIs.

### Why `.strings` files instead of `.xcstrings`?

The project uses SwiftPM (`swift build`), not Xcode's build system. String Catalogs (`.xcstrings`) require Xcode's build pipeline. Traditional `.lproj/Localizable.strings` with `String(localized:bundle:)` works natively with SwiftPM.

### Bundle resolution

The app needs localization to work both in `swift run` (development) and in the packaged `.app` bundle (production). The `L10n.bundle` static property checks whether `.lproj` directories exist in `Bundle.main` (`.app` case), falling back to `Bundle.module` (SPM case).

### Dashboard access

The daemon serves a dashboard at `GET /dashboard` on its configured port. The app header has a button that opens this URL in the browser. This only works when the daemon is running.

### State management: two independent state flows

The app has two independent state flows that must not be mixed:

1. **Runtime status** (`refreshStatus()`): daemon is running/stopped, PID, installed version, channel states. Fast — local shell commands only. Called periodically (30s) and after every user action.

2. **Update check** (`checkForUpdates()`): latest available versions from npm registry. Slow — network requests. Called on popover open and then periodically.

`DaemonViewModel` maintains:
- `status: DaemonStatus` / `channels: [ChannelInfo]` — runtime state, written by `refreshStatus()`
- `latestVersions: [String: String]` — update check results, keyed by `"daemon"` or channel type, written only by `checkForUpdates()`
- `hasUpdate(type:installedVersion:)` — compares the two, used by views

**Critical rule**: user actions (`executeCommand`) call `refreshStatus()` after completion, but **never** call `checkForUpdates()`. Update checking is handled solely by the periodic timer. Mixing them causes the loading spinner to linger (npm network calls are slow) and creates confusing UX where the user sees output but the UI is still "busy".

### Working directory for daemon commands

macOS GUI apps have `cwd = /`, but the duoduo daemon resolves paths relative to `process.cwd()` (e.g., `bootstrapDir` for dashboard.html). `DaemonService` resolves the npm package root via `which duoduo` on every command and sets it as `Process.currentDirectoryURL`. This ensures dashboard routes and other relative-path features work correctly when launched from the menu bar app.

### Config persistence (ConfigStore)

All configuration (daemon settings, Feishu channel settings) uses `ConfigStore` — a shared utility that serializes/deserializes `Codable` types as JSON in `UserDefaults`. This avoids duplicating persistence logic across config models. Only non-default values are mapped to environment variables when starting services.

### Menu bar app lifecycle

The app uses `NSStatusItem` + `NSPopover` with `.transient` behavior (click outside to close). `NSApp.setActivationPolicy(.accessory)` hides the dock icon. The SwiftUI `App` entry point uses a minimal `WindowGroup("")` with `EmptyView` that auto-closes on appear to satisfy the lifecycle requirements.

## Build & Packaging

The `build_app.sh` script handles:

1. **Separate arch builds** — Compiles for arm64 and x86_64 independently (no universal binary, no Rosetta). Each .app bundles the matching Node.js architecture
2. **App bundle assembly** — Copies from `.app-template`, adds executable and resources. Node.js is extracted via `tar` to preserve symlinks
3. **Code signing** — Developer ID signing with entitlements for sandbox access
4. **Notarization** — Submits to Apple's notary service via `notarytool`
5. **DMG creation** — Two separate DMGs: `DuoduoManager-{version}-arm64.dmg` and `DuoduoManager-{version}-x86_64.dmg`

Localization `.lproj` directories are copied into `Contents/Resources/` during app bundle assembly.

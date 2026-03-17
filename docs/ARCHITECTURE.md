# Architecture

## Overview

DuoduoManager follows a standard SwiftUI MVVM pattern:

```
Views → ViewModels → Services → Models
```

```
DuoduoManagerApp.swift (entry point, menu bar lifecycle)
├── StatusBarView.swift        (popover UI)
│   ├── ConfigView.swift       (initial setup window)
│   ├── DaemonConfigView.swift (daemon settings panel)
│   └── FeishuConfigView.swift (Feishu channel settings panel)
├── DaemonViewModel.swift      (single @Observable view model)
├── Services/
│   ├── ShellService.swift     (process execution, PATH loading)
│   ├── DaemonService.swift    (duoduo daemon CLI wrapper)
│   ├── ChannelService.swift   (duoduo channel CLI wrapper)
│   ├── UpgradeService.swift   (npm update orchestration)
│   └── VersionService.swift   (GitHub/npm version queries)
├── Models/
│   ├── DaemonConfig.swift     (daemon settings + env var mapping)
│   ├── DaemonStatus.swift     (runtime status)
│   ├── FeishuConfig.swift     (Feishu channel settings + env var mapping)
│   ├── ChannelInfo.swift      (installed channel runtime info)
│   ├── ChannelRegistry.swift  (channel type registry)
│   └── PackageVersion.swift   (npm package version info)
└── Localization/
    └── L10n.swift             (type-safe localization keys)
```

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

### Config persistence

All configuration (daemon settings, Feishu channel settings) is stored as JSON in `UserDefaults`. The `DaemonConfig` and `FeishuConfig` models map their fields to environment variables (`ALADUO_*`, `FEISHU_*`) which are injected when starting the daemon or channels. Only non-default values are passed, preserving the daemon's own defaults.

### Menu bar app lifecycle

The app uses `NSStatusItem` + `NSPopover` with `.transient` behavior (click outside to close). `NSApp.setActivationPolicy(.accessory)` hides the dock icon. The SwiftUI `App` entry point uses an empty `Settings` scene to satisfy the lifecycle requirements.

## Build & Packaging

The `build_app.sh` script handles:

1. **Universal binary** — Compiles for arm64 and x86_64, merges with `lipo`
2. **App bundle assembly** — Copies from `.app-template`, adds executable and resources
3. **Code signing** — Developer ID signing with entitlements for sandbox access
4. **Notarization** — Submits to Apple's notary service via `notarytool`
5. **DMG creation** — Styled disk image using `create-dmg` (fallback to `hdiutil`)

Localization `.lproj` directories are copied into `Contents/Resources/` during app bundle assembly.

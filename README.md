# DuoduoManager

A macOS menu bar application for managing the [duoduo](https://github.com/openduo/duoduo) daemon and its channels (e.g., Feishu/Lark). Built with SwiftUI for macOS 14+.

## Features

- **Menu bar interface** — Unobtrusive status item with a popover for quick access
- **Self-contained runtime** — Bundled Node.js, no system Node or npm required; duoduo auto-installed on first launch
- **Daemon management** — Start, stop, restart, and configure the duoduo daemon
- **Channel management** — Install, configure, and control messaging channels (currently Feishu)
- **Smart upgrades** — Version-aware: only updates and restarts components with newer versions
- **ATC Dashboard** — Real-time event stream, session monitoring, and job management (Catppuccin Mocha theme)

## Screenshots

![DuoduoManager screenshot](assets/screenshot.png)

![ATC Dashboard](assets/dashboard.png)

## Installation

### Download

Download the DMG for your architecture from [Releases](https://github.com/openduo/duoduo-manager/releases):

- `DuoduoManager-*-arm64.dmg` — Apple Silicon (M1/M2/M3/M4)
- `DuoduoManager-*-x86_64.dmg` — Intel

### From source

```bash
git clone https://github.com/openduo/duoduo-manager.git
cd duoduo-manager
make run        # Build and launch for development
make app        # Build arm64 + x86_64 .app bundles
```

### Prerequisites

- macOS 14 (Sonoma) or later
- Xcode Command Line Tools (`xcode-select --install`)

No need to install Node.js, npm, or duoduo separately — everything is bundled.

## Development

### Build

```bash
make build      # Debug build
make run        # Build and run
make run-release # Build release and run
make clean      # Clean build artifacts
```

### Release

```bash
make app        # Build arm64 + x86_64 .app bundles (no signing)
make dmg        # Create DMG installers for both architectures
make release    # Full release: build + sign + notarize + DMG
```

### Version management

```bash
make version                    # Show current version
make update-version NEW_VERSION=x.y.z
```

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed architecture documentation including runtime environment, daemon lifecycle, and upgrade flow.

## Localization

See [I18N.md](I18N.md) for how to add or modify translations.

## License

MIT

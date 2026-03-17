# DuoduoManager

A macOS menu bar application for managing the [duoduo](https://github.com/openduo/duoduo) daemon and its channels (e.g., Feishu/Lark). Built with SwiftUI for macOS 14+.

## Features

- **Menu bar interface** — Unobtrusive status item with a popover for quick access
- **Daemon management** — Start, stop, restart, and configure the duoduo daemon
- **Channel management** — Install, configure, and control messaging channels (currently Feishu)
- **One-click upgrades** — Update daemon and all channels simultaneously
- **Version tracking** — Automatic checks for new releases via GitHub API and npm
- **Internationalization** — English and Simplified Chinese, follows macOS system language

## Installation

### From source

```bash
git clone https://github.com/openduo/duoduo-manager.git
cd duoduo-manager
make run        # Build and launch for development
make app        # Build universal .app bundle
```

### Prerequisites

- macOS 14 (Sonoma) or later
- Xcode Command Line Tools (`xcode-select --install`)
- [duoduo CLI](https://github.com/openduo/duoduo) installed globally via npm

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
make app        # Build .app bundle (universal binary)
make dmg        # Create DMG installer
make release    # Full release: build + sign + notarize + DMG
```

### Version management

```bash
make version                    # Show current version
make update-version NEW_VERSION=x.y.z
```

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed architecture documentation.

## Localization

See [I18N.md](I18N.md) for how to add or modify translations.

## License

MIT

<p align="center">
  <img src="docs/assets/banner.jpg" alt="AIStatus Banner" width="100%">
</p>

# AIStatus

[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%2015+-blue.svg)](https://developer.apple.com/macos/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Monitor AI service health from your menu bar or terminal.

## What is it?

AIStatus gives you a quick way to check if AI services are up and running. It comes in two flavors:

- **Menu Bar App** — A colored dot that stays in your menu bar. Pick which service to watch — Green = all good, orange = degraded, red = outage, gray = unknown.
- **CLI** — Run `aistatus` in your terminal for a quick status check with colored output.

## Install

### Homebrew

```bash
brew tap MathisDetourbet/tap

# CLI
brew install aistatus

# Menu Bar App
brew install --cask aistatusbar
```

### Download from GitHub Releases

Pre-built universal binaries (arm64 + x86\_64) are available on the [Releases](https://github.com/MathisDetourbet/AIStatus/releases) page.

> **Note:** The app is not yet notarized. On first launch, right-click the app and select "Open" to bypass Gatekeeper.

### From source

```bash
git clone https://github.com/MathisDetourbet/AIStatus.git
cd AIStatus
swift build -c release
```

Run directly:

```bash
# CLI
swift run aistatus

# Menu Bar App
swift run AIStatusBar
```

## CLI Output

```
✓ Claude: operational
✓ OpenAI: operational
✓ Cursor: operational
```

Exit codes: `0` all operational, `1` degraded/outage, `2` unknown/error.

## Supported Services

| Service | Status Page |
|---------|------------|
| Claude | [status.claude.com](https://status.claude.com) |
| OpenAI | [status.openai.com](https://status.openai.com) |
| Cursor | [status.cursor.com](https://status.cursor.com) |

PRs welcome to add more!

## Contributing

Contributions are welcome! Whether it's adding new AI services, improving the UI, or fixing bugs — feel free to open an issue or submit a PR.

1. Fork the repo
2. Create your branch (`git checkout -b my-feature`)
3. Commit your changes
4. Push and open a Pull Request

## License

MIT

# AIStatus

[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%2015+-blue.svg)](https://developer.apple.com/macos/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Monitor AI service health from your menu bar or terminal.

## What is it?

AIStatus gives you a quick way to check if AI services (Claude, and more to come) are up and running. It comes in two flavors:

- **Menu Bar App** — A colored dot that stays in your menu bar. Green = all good, orange = degraded, red = outage, gray = unknown.
- **CLI** — Run `aistatus` in your terminal for a quick status check with colored output.

## Install

### From source

```bash
git clone https://github.com/MathisDetourbet/AIStatus.git
cd AIStatus
swift build
```

### Run directly

```bash
# CLI
swift run aistatus

# Menu Bar App
swift run AIStatusBar
```

## CLI Output

```
✓ Claude: operational
```

Exit codes: `0` all operational, `1` degraded/outage, `2` unknown/error.

## Supported Services

| Service | Status Page |
|---------|------------|
| Claude (Anthropic) | [status.anthropic.com](https://status.anthropic.com) |

More coming soon — PRs welcome!

## Contributing

Contributions are welcome! Whether it's adding new AI services, improving the UI, or fixing bugs — feel free to open an issue or submit a PR.

1. Fork the repo
2. Create your branch (`git checkout -b my-feature`)
3. Commit your changes
4. Push and open a Pull Request

## License

MIT

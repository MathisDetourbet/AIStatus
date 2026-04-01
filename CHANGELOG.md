# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.4.0] - 2026-04-01

### Added

- Multi-AI service monitoring: OpenAI and Cursor alongside Claude
- Service picker in the menu bar to select which provider drives the status dot
- Persistent provider selection via UserDefaults
- Type-safe non-empty provider list using `swift-nonempty`

## [0.3.0] - 2026-03-25

### Added

- App icon for AIStatusBar in Applications folder and Dock
- Auto-update of Homebrew cask on release

### Fixed

- Release pipeline: auto-tag now triggers downstream release workflow

## [0.2.0] - 2026-03-25

### Added

- GitHub Releases with universal macOS binaries (arm64 + x86_64)
- Homebrew tap: `brew install MathisDetourbet/tap/aistatus` (CLI) and `brew install --cask MathisDetourbet/tap/aistatusbar` (menu bar app)
- Automated release pipeline triggered by `release/*` and `hotfix/*` branches
- App bundle packaging for AIStatusBar.app

## [0.1.0] - 2026-03-21

### Added

- Menu bar app with colored dot status indicator (green/orange/red/gray)
- CLI tool with colored output and meaningful exit codes
- Claude (Anthropic) status monitoring via Statuspage.io API
- 30-second automatic polling interval

[0.4.0]: https://github.com/MathisDetourbet/AIStatus/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/MathisDetourbet/AIStatus/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/MathisDetourbet/AIStatus/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/MathisDetourbet/AIStatus/releases/tag/v0.1.0

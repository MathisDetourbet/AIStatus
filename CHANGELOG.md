# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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

[0.2.0]: https://github.com/MathisDetourbet/AIStatus/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/MathisDetourbet/AIStatus/releases/tag/v0.1.0

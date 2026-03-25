---
title: "feat: Add GitHub Releases and Homebrew tap distribution"
type: feat
status: active
date: 2026-03-25
---

# Add GitHub Releases and Homebrew Tap Distribution

## Overview

Enable easy installation of AIStatus without cloning the repo. Two distribution channels:
1. **GitHub Releases** — automated universal binary builds on tag push
2. **Homebrew tap** — `brew install` / `brew install --cask` for CLI and menu bar app

Mac App Store distribution is planned for later and out of scope here.

## Problem Statement

Currently the only way to install AIStatus is `git clone` + `swift build`, which requires Xcode and Swift toolchain. Users should be able to install with a single command or download.

## Proposed Solution

### Phase 1: App bundle packaging + release workflow

Create a shell script that wraps `AIStatusBar` into a proper `.app` bundle, then a GitHub Actions workflow that builds universal binaries and publishes GitHub Releases on tag push.

### Phase 2: Homebrew tap

Create `MathisDetourbet/homebrew-tap` repository with a Formula (CLI) and Cask (menu bar app), auto-updated on release.

### Phase 3 (later): Code signing + notarization

Add Developer ID signing and notarization to eliminate Gatekeeper warnings. This requires an Apple Developer account and is optional for initial releases.

## Acceptance Criteria

- [x] `scripts/bundle-app.sh` creates a working `AIStatusBar.app` from SwiftPM build output
- [x] `.github/workflows/release.yml` triggers on `v*.*.*` tag push
- [x] Release workflow builds universal (arm64 + x86_64) binaries
- [x] Release workflow creates `.app` bundle, archives both products, generates SHA-256 checksums
- [x] GitHub Release is created with: `AIStatusBar-<version>-macos-universal.zip`, `aistatus-<version>-macos-universal.tar.gz`, `checksums-sha256.txt`
- [ ] `MathisDetourbet/homebrew-tap` repo exists with Formula and Cask
- [ ] `brew install MathisDetourbet/tap/aistatus` installs the CLI
- [ ] `brew install --cask MathisDetourbet/tap/aistatusbar` installs the menu bar app
- [x] Release workflow auto-updates Homebrew formula/cask on new release

## Technical Approach

### 1. App Bundle Script (`scripts/bundle-app.sh`)

Assembles `AIStatusBar.app` from SwiftPM build output:

```
AIStatusBar.app/
  Contents/
    Info.plist          # LSUIElement=true, CFBundleIdentifier, version from arg
    MacOS/
      AIStatusBar       # Universal binary
    Resources/
      AIStatus_AIStatusBar.bundle/   # SPM resource bundle (dot images)
```

Key details:
- `Info.plist` with `LSUIElement: true` (agent app, no Dock icon)
- Version passed as argument: `./scripts/bundle-app.sh 1.0.0`
- `Bundle.module` resolves resources from `Contents/Resources/` inside the `.app`
- `CFBundleIdentifier`: `com.mathisdetourbet.AIStatusBar`

### 2. Release Workflow (`.github/workflows/release.yml`)

```
Trigger: push tag v*.*.*
Runner: macos-15 (or macos-26 to match CI)

Steps:
  1. Checkout
  2. Extract version from tag (strip 'v' prefix)
  3. Build universal: swift build -c release --arch arm64 --arch x86_64
  4. Run scripts/bundle-app.sh with version
  5. Archive:
     - ditto -c -k --keepParent → AIStatusBar-<ver>-macos-universal.zip
     - tar -czf → aistatus-<ver>-macos-universal.tar.gz
  6. Generate SHA-256 checksums
  7. Create GitHub Release (softprops/action-gh-release@v2, generate_release_notes: true)
  8. Update Homebrew tap (mislav/bump-homebrew-formula-action@v3)
```

**Universal binary path**: when using `--arch arm64 --arch x86_64`, output is at `.build/apple/Products/Release/` (not the usual `.build/release/`).

Use `ditto` for the `.app` zip (preserves macOS metadata). Use `tar` for the CLI (Homebrew convention).

### 3. Homebrew Tap (`MathisDetourbet/homebrew-tap`)

Separate GitHub repository with:

**`Formula/aistatus.rb`** — downloads pre-built CLI binary from GitHub Release:
```ruby
class Aistatus < Formula
  desc "Check AI service status from the command line"
  homepage "https://github.com/MathisDetourbet/AIStatus"
  url "https://github.com/MathisDetourbet/AIStatus/releases/download/v{version}/aistatus-{version}-macos-universal.tar.gz"
  sha256 "..."
  license "MIT"

  def install
    bin.install "aistatus"
  end
end
```

**`Casks/aistatusbar.rb`** — downloads `.app` zip:
```ruby
cask "aistatusbar" do
  version "1.0.0"
  sha256 "..."
  url "https://github.com/MathisDetourbet/AIStatus/releases/download/v#{version}/AIStatusBar-#{version}-macos-universal.zip"
  name "AIStatusBar"
  desc "Menu bar app showing AI service status"
  homepage "https://github.com/MathisDetourbet/AIStatus"
  depends_on macos: ">= :sequoia"
  app "AIStatusBar.app"
end
```

Auto-update: the release workflow uses `mislav/bump-homebrew-formula-action@v3` to commit updated formula to the tap repo. Requires a `HOMEBREW_TAP_TOKEN` (PAT with `public_repo` scope) secret.

### 4. Code Signing (Phase 3, later)

When ready (requires Apple Developer account, $99/year):
- Add `Developer ID Application` certificate as base64 GitHub secret
- Insert signing steps between build and archive: `codesign --force --options runtime`
- Notarize with `xcrun notarytool submit --wait` + `xcrun stapler staple`
- Critical: `--options runtime` (Hardened Runtime) is required for notarization

Without signing, users will see Gatekeeper "unidentified developer" warning and must right-click → Open. The CLI tool is unaffected (Terminal bypasses Gatekeeper).

## Implementation Steps

### Step 1: Create `scripts/bundle-app.sh`
- Shell script to assemble `.app` bundle
- Test locally: build, run script, verify `AIStatusBar.app` launches and shows menu bar icon

### Step 2: Create `.github/workflows/release.yml`
- Tag-triggered workflow
- Build universal binaries
- Run bundle script
- Archive and checksum
- Create GitHub Release
- **Do NOT include Homebrew update step yet** (tap repo doesn't exist)

### Step 3: Test with a tag push
- Push `v0.2.0` tag
- Verify GitHub Release is created with correct artifacts
- Download and test both products on a Mac

### Step 4: Create `MathisDetourbet/homebrew-tap` repository
- This is a manual step (create repo on GitHub)
- Add `Formula/aistatus.rb` and `Casks/aistatusbar.rb` pointing to the release

### Step 5: Add Homebrew auto-update to release workflow
- Add `mislav/bump-homebrew-formula-action@v3` step
- Add `HOMEBREW_TAP_TOKEN` secret to AIStatus repo
- Test with next tag push

### Step 6: Update README
- Add Homebrew install instructions
- Add GitHub Releases download link
- Keep "build from source" as alternative

## Dependencies & Risks

- **`Bundle.module` resolution in `.app`**: SPM's `Bundle.module` must find the resource bundle inside `Contents/Resources/`. Needs testing — may require placing the bundle next to the binary in `Contents/MacOS/` instead.
- **macOS runner availability**: `macos-15` or `macos-26` runners must support Swift 6.2. If not, fall back to `macos-latest`.
- **Universal binary build path**: output at `.build/apple/Products/Release/` differs from single-arch `.build/release/`. The bundle script must use the correct path.
- **Unsigned app warnings**: without notarization, the `.app` will trigger Gatekeeper. Document the right-click workaround in README until signing is added.
- **Homebrew tap repo is external**: the tap is a separate repo that must be created manually on GitHub before the auto-update step works.

## Sources & References

- Existing CI: `.github/workflows/ci.yml`
- Design doc: `docs/plans/2026-03-18-aistatus-design.md`
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release)
- [mislav/bump-homebrew-formula-action](https://github.com/mislav/bump-homebrew-formula-action)
- [Homebrew Tap docs](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- [Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)

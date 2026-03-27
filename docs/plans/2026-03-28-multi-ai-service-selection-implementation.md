# Multi-AI Service Selection Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let users select which AI service (Claude, OpenAI, Cursor) drives the menu bar dot, with all services listed in the menu showing their individual status dots.

**Architecture:** Extend existing `StatusMonitor` with a `selectedProviderName` property persisted in `UserDefaults`. All providers are polled simultaneously. The menu bar dot reflects the selected service. The menu lists all services with status dots and a checkmark on the selected one.

**Tech Stack:** Swift 6.2, SwiftUI, Observation, UserDefaults

---

### Task 1: Add OpenAI and Cursor providers

**Files:**
- Modify: `Sources/AIStatusKit/AI.swift:1-10`

**Step 1: Write the failing test**

Create file `Tests/AIStatusKitTests/AITests.swift`:

```swift
import Testing
@testable import AIStatusKit

@Test func `AI.all contains three providers`() {
    #expect(AI.all.count == 3)
}

@Test func `AI providers have correct names`() {
    let names = AI.all.map(\.name)
    #expect(names.contains("Claude"))
    #expect(names.contains("OpenAI"))
    #expect(names.contains("Cursor"))
}

@Test func `AI providers have correct base URLs`() {
    #expect(AI.claude.baseURL.absoluteString == "https://status.claude.com")
    #expect(AI.openai.baseURL.absoluteString == "https://status.openai.com")
    #expect(AI.cursor.baseURL.absoluteString == "https://status.cursor.com")
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter AITests`
Expected: FAIL — `openai` and `cursor` do not exist on `AI`

**Step 3: Write minimal implementation**

Replace `Sources/AIStatusKit/AI.swift` with:

```swift
import Foundation

public enum AI {
    public static let claude = StatuspageProvider(
        name: "Claude",
        baseURL: URL(string: "https://status.claude.com")!
    )

    public static let openai = StatuspageProvider(
        name: "OpenAI",
        baseURL: URL(string: "https://status.openai.com")!
    )

    public static let cursor = StatuspageProvider(
        name: "Cursor",
        baseURL: URL(string: "https://status.cursor.com")!
    )

    public static let all: [any StatusProvider] = [claude, openai, cursor]
}
```

**Step 4: Run test to verify it passes**

Run: `swift test --filter AITests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/AIStatusKit/AI.swift Tests/AIStatusKitTests/AITests.swift
git commit -m "feat: add OpenAI and Cursor status providers"
```

---

### Task 2: Add selected provider to StatusMonitor

**Files:**
- Modify: `Sources/AIStatusKit/StatusMonitor.swift:1-55`
- Modify: `Tests/AIStatusKitTests/StatusMonitorTests.swift`

**Step 1: Write the failing tests**

Add to `Tests/AIStatusKitTests/StatusMonitorTests.swift`:

```swift
@Test func `selectedProviderName defaults to Claude`() async {
    let monitor = await StatusMonitor(providers: [
        StubProvider(name: "Claude", result: .operational),
    ])
    let selected = await monitor.selectedProviderName
    #expect(selected == "Claude")
}

@Test func `selectedStatus reflects selected provider`() async {
    let monitor = await StatusMonitor(providers: [
        StubProvider(name: "Claude", result: .operational),
        StubProvider(name: "OpenAI", result: .major),
    ])
    await monitor.refresh()
    await monitor.selectProvider(named: "OpenAI")
    let status = await monitor.selectedStatus
    #expect(status == .major)
}

@Test func `selectedStatus returns unknown for missing provider`() async {
    let monitor = await StatusMonitor(providers: [
        StubProvider(name: "Claude", result: .operational),
    ])
    await monitor.refresh()
    await monitor.selectProvider(named: "NonExistent")
    let status = await monitor.selectedStatus
    #expect(status == .unknown)
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter StatusMonitorTests`
Expected: FAIL — `selectedProviderName`, `selectedStatus`, `selectProvider` do not exist

**Step 3: Write minimal implementation**

Update `Sources/AIStatusKit/StatusMonitor.swift`:

```swift
import Foundation
import Observation

@Observable
@MainActor
public final class StatusMonitor {
    public private(set) var statuses: [String: AIStatus] = [:]
    public private(set) var selectedProviderName: String
    private let providers: [any StatusProvider]
    private let interval: TimeInterval
    private var task: Task<Void, Never>?
    private let defaults: UserDefaults

    public var overallStatus: AIStatus {
        AIStatus.worst(Array(statuses.values))
    }

    public var selectedStatus: AIStatus {
        statuses[selectedProviderName] ?? .unknown
    }

    public init(
        providers: [any StatusProvider],
        interval: TimeInterval = 30,
        defaults: UserDefaults = .standard
    ) {
        self.providers = providers
        self.interval = interval
        self.defaults = defaults
        self.selectedProviderName = defaults.string(forKey: "selectedProvider") ?? "Claude"
        startMonitoring()
    }

    public func selectProvider(named name: String) {
        selectedProviderName = name
        defaults.set(name, forKey: "selectedProvider")
    }

    public func refresh() async {
        await withTaskGroup(of: (String, AIStatus).self) { group in
            for provider in providers {
                group.addTask {
                    do {
                        let status = try await provider.fetchStatus()
                        return (provider.name, status)
                    } catch {
                        print("[AIStatus] \(provider.name) fetch failed: \(error)")
                        return (provider.name, .unknown)
                    }
                }
            }
            for await (name, status) in group {
                statuses[name] = status
            }
        }
    }

    public func startMonitoring() {
        task = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    public func stopMonitoring() {
        task?.cancel()
        task = nil
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter StatusMonitorTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/AIStatusKit/StatusMonitor.swift Tests/AIStatusKitTests/StatusMonitorTests.swift
git commit -m "feat: add selected provider support to StatusMonitor"
```

---

### Task 3: Update menu UI to show all services

**Files:**
- Modify: `Sources/AIStatusBar/StatusMenuContent.swift:1-13`

**Step 1: Write the implementation**

No unit test for SwiftUI view — verify manually. Replace `Sources/AIStatusBar/StatusMenuContent.swift`:

```swift
import SwiftUI
import AIStatusKit

struct StatusMenuContent: View {
    @Bindable var monitor: StatusMonitor

    var body: some View {
        ForEach(monitor.providers, id: \.name) { provider in
            let status = monitor.statuses[provider.name] ?? .unknown
            Button {
                monitor.selectProvider(named: provider.name)
            } label: {
                HStack {
                    Image(status.dotImageName, bundle: Bundle.module(for: AIStatusKit.self))
                        .renderingMode(.original)
                    Text(provider.name)
                    Spacer()
                    if provider.name == monitor.selectedProviderName {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
```

Note: The exact `Bundle` reference for loading dot images from `AIStatusBar`'s asset catalog may need adjustment. The dot images are in `Sources/AIStatusBar/Resources/Assets.xcassets`, so `Bundle.module` (from `StatusMenuContent`'s module) should work. If images are in `AIStatusKit`, use the kit's bundle. Verify at runtime.

**Step 2: Expose providers from StatusMonitor**

The view needs access to `monitor.providers`. Add a public accessor in `Sources/AIStatusKit/StatusMonitor.swift`. Change the `providers` property from `private` to `public private(set)`:

```swift
// Change:
private let providers: [any StatusProvider]
// To:
public let providers: [any StatusProvider]
```

**Step 3: Run the app to verify**

Run: `swift build --product AIStatusBar && .build/debug/AIStatusBar`

Verify:
- Menu shows Claude, OpenAI, Cursor with status dots
- Tapping a service shows a checkmark and changes the menu bar dot
- Quit button still works

**Step 4: Commit**

```bash
git add Sources/AIStatusBar/StatusMenuContent.swift Sources/AIStatusKit/StatusMonitor.swift
git commit -m "feat: show all AI services in menu with selection"
```

---

### Task 4: Update menu bar dot to use selected status

**Files:**
- Modify: `Sources/AIStatusBar/AIStatusBarApp.swift:1-21`

**Step 1: Update the app**

Replace `Sources/AIStatusBar/AIStatusBarApp.swift`:

```swift
import SwiftUI
import AIStatusKit

@main
struct AIStatusBarApp: App {
    @State private var monitor = StatusMonitor(providers: AI.all)

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            StatusMenuContent(monitor: monitor)
        } label: {
            Image(monitor.selectedStatus.dotImageName, bundle: .module)
                .renderingMode(.original)
        }
        .menuBarExtraStyle(.menu)
    }
}
```

Only change: `monitor.overallStatus` → `monitor.selectedStatus` on line 16.

**Step 2: Build and verify**

Run: `swift build --product AIStatusBar`
Expected: Compiles without errors

**Step 3: Run all tests**

Run: `swift test`
Expected: All tests pass

**Step 4: Commit**

```bash
git add Sources/AIStatusBar/AIStatusBarApp.swift
git commit -m "feat: menu bar dot reflects selected AI service"
```

---

### Task 5: Final integration test

**Step 1: Run full test suite**

Run: `swift test`
Expected: All tests pass

**Step 2: Manual smoke test**

Run: `swift build --product AIStatusBar && .build/debug/AIStatusBar`

Verify:
1. App launches with dot in menu bar (Claude selected by default)
2. Click dot — menu shows Claude, OpenAI, Cursor with status dots
3. Claude has checkmark
4. Click OpenAI — checkmark moves, dot may change color
5. Quit and relaunch — OpenAI still selected (UserDefaults persistence)
6. Click Quit — app terminates

**Step 3: Final commit if any adjustments needed**

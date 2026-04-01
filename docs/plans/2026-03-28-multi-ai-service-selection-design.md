# Multi-AI Service Selection

## Summary

Allow users to select which AI service's status drives the menu bar dot. The menu displays all supported services with their individual status dots, and tapping one selects it as the active service.

## Supported Services

| Service | Status URL | Provider |
|---------|-----------|----------|
| Claude | status.claude.com | StatuspageProvider (existing) |
| OpenAI | status.openai.com | StatuspageProvider |
| Cursor | status.cursor.com | StatuspageProvider |

All three use Statuspage.io — no new provider types needed.

## Data Layer

**`AI` enum** — Add OpenAI and Cursor:

```swift
public static let openai = StatuspageProvider(name: "OpenAI", baseURL: URL(string: "https://status.openai.com")!)
public static let cursor = StatuspageProvider(name: "Cursor", baseURL: URL(string: "https://status.cursor.com")!)
public static let all: [any StatusProvider] = [claude, openai, cursor]
```

No changes to `StatuspageProvider`, `StatusProvider` protocol, or `StatusResponse`.

## State Management

**`StatusMonitor`** additions:

- `selectedProviderName: String` — name of the active service, persisted in `UserDefaults` (key: `"selectedProvider"`), defaults to `"Claude"`
- `selectedStatus: AIStatus` — computed from `statuses[selectedProviderName]`, falls back to `.unknown`

The menu bar dot reads `selectedStatus` instead of `overallStatus`.

All providers are polled every 30s regardless of selection (lightweight GET requests).

## Menu UI

**`StatusMenuContent`** updated to show:

```
┌─────────────────────┐
│ ● Claude        ✓   │
│ ● OpenAI            │
│ ● Cursor            │
│─────────────────────│
│ Quit            ⌘Q  │
└─────────────────────┘
```

- Each row: status dot image + service name
- Selected service shows a checkmark
- Tapping a service updates `selectedProviderName`
- Divider before Quit button

## Persistence

`UserDefaults` with key `"selectedProvider"`. Read on launch, written on selection change. Just a string — no Keychain needed.

## Approach

Extend existing architecture (Approach A): poll all providers simultaneously, use selection only to determine which status drives the dot. All statuses always fresh, simple code, negligible network overhead.

# Real-Time Claude Usage

## Summary

Display the user's personal Claude plan usage — the same 5-hour session % and weekly % that Claude Code's `/usage` shows — in real time. The percentage is always visible in the menu bar next to the status dot, with a detailed breakdown in the dropdown menu.

## Data Source

Usage comes from Anthropic's OAuth usage endpoint, authenticated by reusing Claude Code's existing credentials:

- **Credentials:** macOS Keychain generic password, service `"Claude Code-credentials"`. The item's data is JSON containing `claudeAiOauth.accessToken` and `claudeAiOauth.expiresAt`.
- **Endpoint:** `GET https://api.anthropic.com/api/oauth/usage`
- **Required headers:**
  - `Authorization: Bearer <accessToken>`
  - `anthropic-beta: oauth-2025-04-20`
  - `User-Agent: claude-code/<version>` — critical; without it requests land in an aggressively rate-limited bucket and 429 persistently.
- **Response** (decode every field as optional — the endpoint is undocumented and may change):
  - `five_hour: { utilization: Int, resets_at: ISO8601 }`
  - `seven_day: { utilization: Int, resets_at: ISO8601 }`
  - `seven_day_opus` and other model-specific buckets (ignored in v1 unless present and trivially displayable)
- **Polling:** every 180 seconds (community-established safe interval), plus a refresh whenever the menu opens.

**v1 requires Claude Code installed and logged in.** If credentials are absent, the app shows a friendly empty state. A standalone sign-in flow (own OAuth or claude.ai cookie paste) is deliberately out of scope: Anthropic's consumer terms prohibit third-party use of consumer OAuth tokens, and the cookie approach is fiddly and fragile. The Keychain-reuse pattern is the same one used by established community apps (claude-meter, Claude-Usage-Tracker).

The first Keychain read triggers macOS's one-time permission dialog ("AIStatusBar wants to access…"); the user clicks "Always Allow" once.

## Data Layer (AIStatusKit)

**`UsageSnapshot`** — value model, leniently decoded:

```swift
public struct UsageSnapshot: Sendable, Equatable {
    public let sessionUtilization: Int?      // five_hour.utilization, 0–100
    public let sessionResetsAt: Date?
    public let weeklyUtilization: Int?       // seven_day.utilization, 0–100
    public let weeklyResetsAt: Date?

    /// The binding constraint — max of session and weekly.
    public var limitingUtilization: Int? { ... }
}
```

**`ClaudeCredentialsReading`** — protocol so the Keychain is mockable in tests:

```swift
public protocol ClaudeCredentialsReading: Sendable {
    func readCredentials() throws -> ClaudeCredentials  // accessToken + expiresAt
}
```

`KeychainClaudeCredentialsReader` implements it with the Security framework. Distinct errors for "item not found" vs "unreadable/malformed" so the UI can show the right message.

**`ClaudeUsageProvider`** — fetches and decodes the endpoint. Behind a `UsageProviding` protocol (`func fetchUsage() async throws -> UsageSnapshot`) for testability. Typed errors: `noCredentials`, `tokenExpired` (401 or past `expiresAt`), `rateLimited` (429), `network`.

**`UsageMonitor`** — `@Observable @MainActor`, mirrors `StatusMonitor`'s polling pattern:

```swift
public enum UsageState: Equatable {
    case noCredentials          // Claude Code not installed / not logged in
    case tokenExpired           // "Run `claude` to refresh"
    case available(UsageSnapshot)
    case stale(UsageSnapshot)   // last fetch failed; showing last known value
    case unavailable            // no data yet and fetch failed
}
```

- Polls every 180s; `refresh()` for on-demand updates.
- On 429: back off to 600s until a success.
- On network failure with a previous snapshot: transition to `.stale` (keep showing numbers).
- Kept separate from `StatusMonitor` — different interval, auth, and failure modes.

## Menu Bar Label

The `MenuBarExtra` label becomes dot + percentage text:

```
● 61%
```

- The number is `limitingUtilization` — the max of session and weekly %, i.e. the limit the user will hit first. Showing only the session % would mislead when the weekly cap is nearly exhausted.
- When usage is `.stale`, the last known % still shows.
- When usage is unavailable in any other way, the label falls back to the dot alone — the app looks exactly as it does today.

## Menu UI

`StatusMenuContent` gains a usage section. The app keeps `menuBarExtraStyle(.menu)`; native menus can't render custom progress bars reliably, so usage is shown as disabled informational rows:

```
┌────────────────────────────────┐
│ ● Claude                   ✓   │
│ ● OpenAI                       │
│ ● Cursor                       │
│────────────────────────────────│
│ Claude Usage                   │
│ Session (5h)   42% · resets 3 PM│
│ Week           61% · resets Tue │
│────────────────────────────────│
│ Quit                       ⌘Q  │
└────────────────────────────────┘
```

- Reset times formatted relative to now: same-day → time (`3 PM`), otherwise weekday (`Tue`).
- A row whose field is missing from the response is simply omitted.
- Empty states replace the two rows with a single line:
  - `noCredentials` → "Install Claude Code and sign in to see usage"
  - `tokenExpired` → "Run `claude` in a terminal to refresh"
  - `stale` → rows show with a "(last known)" suffix on the header
- Opening the menu triggers `UsageMonitor.refresh()`.

## Error Handling

| Condition | Behavior |
|-----------|----------|
| Keychain item missing | `.noCredentials`, dot-only label, install hint in menu |
| 401 / token past expiry | `.tokenExpired`, dot-only label, refresh hint in menu |
| 429 | Keep current state, back off polling to 600s |
| Network error, have data | `.stale`, keep showing last values |
| Missing response fields | Omit that row only; `limitingUtilization` uses what exists |

The app never refreshes the OAuth token itself — Claude Code owns the credential lifecycle.

## Testing

Swift Testing with backtick-quoted descriptive names:

- `UsageSnapshot` decoding from JSON fixtures: full response, partial response, empty object, unknown extra fields.
- Credentials JSON parsing: valid, malformed, missing `claudeAiOauth` key.
- `UsageMonitor` state transitions with a mock `UsageProviding`: success → `.available`, failure-after-success → `.stale`, 401 → `.tokenExpired`, missing credentials → `.noCredentials`, 429 backoff.
- `limitingUtilization` logic: both present, one missing, both missing.

The Keychain reader itself is thin glue and covered by manual testing.

## Risks

- **Unofficial endpoint.** Mitigated by fully-optional decoding, graceful degradation to dot-only, and the same usage pattern as established community tools.
- **User-Agent version drift.** The `claude-code/<version>` string is a single constant, easy to bump.

## Out of Scope (deliberate)

- CLI usage output (`aistatus`)
- OpenAI / Cursor quota tracking
- Standalone auth (cookie paste or own OAuth flow)
- Progress bars / window-style menu redesign

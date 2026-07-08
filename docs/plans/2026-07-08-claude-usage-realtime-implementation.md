# Real-Time Claude Usage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the user's Claude plan usage (5-hour session % and weekly %) live in the menu bar and dropdown, sourced from Anthropic's OAuth usage endpoint via Claude Code's Keychain credentials.

**Architecture:** New `AIStatusKit` components mirror the existing `StatusMonitor` pattern: a leniently-decoded `UsageSnapshot` model, a mockable Keychain credentials reader, a `ClaudeUsageProvider` hitting `GET https://api.anthropic.com/api/oauth/usage`, and an `@Observable @MainActor UsageMonitor` polling every 180s (600s backoff on 429). The menu bar label becomes dot + `limitingUtilization` %; the dropdown gains a text-row usage section.

**Tech Stack:** Swift 6.2, SwiftPM, Swift Testing (backtick-quoted test names), SwiftUI `MenuBarExtra` (`.menu` style), Security framework.

**Spec:** `docs/plans/2026-07-07-claude-usage-realtime-design.md`

**Conventions to follow:**
- Tests use Swift Testing with backtick-quoted descriptive names: `@Test func \`decodes full response\`()`.
- Network mocking uses the existing `URLSession.mock(data:statusCode:error:)` helper in `Tests/AIStatusKitTests/Helpers/MockURLSession.swift`.
- Run tests with `swift test` from the repo root (suite is small and fast).

---

### Task 0: Create feature branch

- [ ] **Step 1: Branch off main**

```bash
cd /Users/mathis/Documents/Perso/dev/AIStatus
git checkout -b feat/claude-usage
```

---

### Task 1: UsageSnapshot model with lenient decoding

**Files:**
- Create: `Sources/AIStatusKit/Models/UsageSnapshot.swift`
- Create: `Tests/AIStatusKitTests/UsageSnapshotTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/AIStatusKitTests/UsageSnapshotTests.swift`:

```swift
import Foundation
import Testing
@testable import AIStatusKit

@Suite("Usage Snapshot")
struct UsageSnapshotTests {
    @Test func `decodes full response`() throws {
        let json = """
        {
            "five_hour": { "utilization": 42, "resets_at": "2026-07-08T15:00:00Z" },
            "seven_day": { "utilization": 61.4, "resets_at": "2026-07-14T00:00:00.000Z" }
        }
        """.data(using: .utf8)!
        let snapshot = try UsageSnapshot(data: json)
        #expect(snapshot.sessionUtilization == 42)
        #expect(snapshot.weeklyUtilization == 61)
        #expect(snapshot.sessionResetsAt == ISO8601DateFormatter().date(from: "2026-07-08T15:00:00Z"))
        #expect(snapshot.weeklyResetsAt == ISO8601DateFormatter().date(from: "2026-07-14T00:00:00Z"))
    }

    @Test func `decodes partial response with missing window`() throws {
        let json = """
        { "five_hour": { "utilization": 12 } }
        """.data(using: .utf8)!
        let snapshot = try UsageSnapshot(data: json)
        #expect(snapshot.sessionUtilization == 12)
        #expect(snapshot.sessionResetsAt == nil)
        #expect(snapshot.weeklyUtilization == nil)
        #expect(snapshot.weeklyResetsAt == nil)
    }

    @Test func `decodes empty object to all nil`() throws {
        let snapshot = try UsageSnapshot(data: "{}".data(using: .utf8)!)
        #expect(snapshot.sessionUtilization == nil)
        #expect(snapshot.weeklyUtilization == nil)
    }

    @Test func `tolerates unknown fields and unexpected types`() throws {
        let json = """
        {
            "five_hour": { "utilization": "oops", "resets_at": 12345, "extra": true },
            "seven_day": { "utilization": 88, "resets_at": "not-a-date" },
            "seven_day_opus": { "utilization": 5 }
        }
        """.data(using: .utf8)!
        let snapshot = try UsageSnapshot(data: json)
        #expect(snapshot.sessionUtilization == nil)
        #expect(snapshot.sessionResetsAt == nil)
        #expect(snapshot.weeklyUtilization == 88)
        #expect(snapshot.weeklyResetsAt == nil)
    }

    @Test func `limiting utilization is max of both windows`() {
        let snapshot = UsageSnapshot(sessionUtilization: 42, sessionResetsAt: nil, weeklyUtilization: 61, weeklyResetsAt: nil)
        #expect(snapshot.limitingUtilization == 61)
    }

    @Test func `limiting utilization falls back to the only present window`() {
        let sessionOnly = UsageSnapshot(sessionUtilization: 42, sessionResetsAt: nil, weeklyUtilization: nil, weeklyResetsAt: nil)
        #expect(sessionOnly.limitingUtilization == 42)
        let weeklyOnly = UsageSnapshot(sessionUtilization: nil, sessionResetsAt: nil, weeklyUtilization: 61, weeklyResetsAt: nil)
        #expect(weeklyOnly.limitingUtilization == 61)
    }

    @Test func `limiting utilization is nil when both windows missing`() {
        let snapshot = UsageSnapshot(sessionUtilization: nil, sessionResetsAt: nil, weeklyUtilization: nil, weeklyResetsAt: nil)
        #expect(snapshot.limitingUtilization == nil)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: compile FAILURE — `cannot find 'UsageSnapshot' in scope`

- [ ] **Step 3: Write the implementation**

Create `Sources/AIStatusKit/Models/UsageSnapshot.swift`:

```swift
import Foundation

public struct UsageSnapshot: Sendable, Equatable {
    public let sessionUtilization: Int?
    public let sessionResetsAt: Date?
    public let weeklyUtilization: Int?
    public let weeklyResetsAt: Date?

    public init(
        sessionUtilization: Int?,
        sessionResetsAt: Date?,
        weeklyUtilization: Int?,
        weeklyResetsAt: Date?
    ) {
        self.sessionUtilization = sessionUtilization
        self.sessionResetsAt = sessionResetsAt
        self.weeklyUtilization = weeklyUtilization
        self.weeklyResetsAt = weeklyResetsAt
    }

    /// The limit the user will hit first — max of session and weekly utilization.
    public var limitingUtilization: Int? {
        switch (sessionUtilization, weeklyUtilization) {
        case let (session?, weekly?): max(session, weekly)
        case let (session?, nil): session
        case let (nil, weekly?): weekly
        case (nil, nil): nil
        }
    }
}

extension UsageSnapshot {
    /// Decodes the `/api/oauth/usage` response. The endpoint is undocumented,
    /// so every field is optional and type mismatches degrade to nil.
    public init(data: Data) throws {
        let response = try JSONDecoder().decode(UsageResponse.self, from: data)
        self.init(
            sessionUtilization: response.fiveHour?.utilization.map { Int($0.rounded()) },
            sessionResetsAt: response.fiveHour?.resetsAt,
            weeklyUtilization: response.sevenDay?.utilization.map { Int($0.rounded()) },
            weeklyResetsAt: response.sevenDay?.resetsAt
        )
    }
}

struct UsageResponse: Decodable {
    struct Window: Decodable {
        let utilization: Double?
        let resetsAt: Date?

        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            utilization = (try? container.decodeIfPresent(Double.self, forKey: .utilization)) ?? nil
            let raw = (try? container.decodeIfPresent(String.self, forKey: .resetsAt)) ?? nil
            resetsAt = raw.flatMap(Self.parseISO8601)
        }

        static func parseISO8601(_ string: String) -> Date? {
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return fractional.date(from: string) ?? ISO8601DateFormatter().date(from: string)
        }
    }

    let fiveHour: Window?
    let sevenDay: Window?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fiveHour = (try? container.decodeIfPresent(Window.self, forKey: .fiveHour)) ?? nil
        sevenDay = (try? container.decodeIfPresent(Window.self, forKey: .sevenDay)) ?? nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS (all suites)

- [ ] **Step 5: Commit**

```bash
git add Sources/AIStatusKit/Models/UsageSnapshot.swift Tests/AIStatusKitTests/UsageSnapshotTests.swift
git commit -m "feat: add UsageSnapshot model with lenient decoding"
```

---

### Task 2: ClaudeCredentials parsing

**Files:**
- Create: `Sources/AIStatusKit/Models/ClaudeCredentials.swift`
- Create: `Tests/AIStatusKitTests/ClaudeCredentialsTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/AIStatusKitTests/ClaudeCredentialsTests.swift`:

```swift
import Foundation
import Testing
@testable import AIStatusKit

@Suite("Claude Credentials")
struct ClaudeCredentialsTests {
    @Test func `parses access token and millisecond expiry`() throws {
        let json = """
        { "claudeAiOauth": { "accessToken": "sk-ant-oat01-abc", "refreshToken": "sk-ant-ort01-xyz", "expiresAt": 1783609200000 } }
        """.data(using: .utf8)!
        let credentials = try ClaudeCredentials(json: json)
        #expect(credentials.accessToken == "sk-ant-oat01-abc")
        #expect(credentials.expiresAt == Date(timeIntervalSince1970: 1_783_609_200))
    }

    @Test func `parses credentials without expiry`() throws {
        let json = """
        { "claudeAiOauth": { "accessToken": "sk-ant-oat01-abc" } }
        """.data(using: .utf8)!
        let credentials = try ClaudeCredentials(json: json)
        #expect(credentials.accessToken == "sk-ant-oat01-abc")
        #expect(credentials.expiresAt == nil)
    }

    @Test func `malformed JSON throws unreadable`() {
        #expect(throws: CredentialsError.unreadable) {
            try ClaudeCredentials(json: "not json".data(using: .utf8)!)
        }
    }

    @Test func `missing claudeAiOauth key throws unreadable`() {
        let json = """
        { "other": {} }
        """.data(using: .utf8)!
        #expect(throws: CredentialsError.unreadable) {
            try ClaudeCredentials(json: json)
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: compile FAILURE — `cannot find 'ClaudeCredentials' in scope`

- [ ] **Step 3: Write the implementation**

Create `Sources/AIStatusKit/Models/ClaudeCredentials.swift`:

```swift
import Foundation

public struct ClaudeCredentials: Sendable, Equatable {
    public let accessToken: String
    public let expiresAt: Date?

    public init(accessToken: String, expiresAt: Date?) {
        self.accessToken = accessToken
        self.expiresAt = expiresAt
    }
}

public enum CredentialsError: Error, Equatable {
    case notFound
    case unreadable
}

public protocol ClaudeCredentialsReading: Sendable {
    func readCredentials() throws -> ClaudeCredentials
}

extension ClaudeCredentials {
    /// Parses the JSON Claude Code stores in the Keychain item "Claude Code-credentials":
    /// `{"claudeAiOauth": {"accessToken": "...", "expiresAt": <epoch milliseconds>, ...}}`
    init(json data: Data) throws {
        struct Wrapper: Decodable {
            struct OAuth: Decodable {
                let accessToken: String
                let expiresAt: Double?
            }
            let claudeAiOauth: OAuth
        }
        guard let wrapper = try? JSONDecoder().decode(Wrapper.self, from: data) else {
            throw CredentialsError.unreadable
        }
        self.init(
            accessToken: wrapper.claudeAiOauth.accessToken,
            expiresAt: wrapper.claudeAiOauth.expiresAt.map { Date(timeIntervalSince1970: $0 / 1000) }
        )
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/AIStatusKit/Models/ClaudeCredentials.swift Tests/AIStatusKitTests/ClaudeCredentialsTests.swift
git commit -m "feat: add ClaudeCredentials parsing and reader protocol"
```

---

### Task 3: Keychain credentials reader

Thin Security-framework glue — no unit tests (covered by manual verification in Task 7).

**Files:**
- Create: `Sources/AIStatusKit/Providers/KeychainClaudeCredentialsReader.swift`

- [ ] **Step 1: Write the implementation**

Create `Sources/AIStatusKit/Providers/KeychainClaudeCredentialsReader.swift`:

```swift
import Foundation
import Security

/// Reads the OAuth credentials Claude Code stores in the login Keychain.
/// First access triggers macOS's one-time permission dialog.
public struct KeychainClaudeCredentialsReader: ClaudeCredentialsReading {
    static let service = "Claude Code-credentials"

    public init() {}

    public func readCredentials() throws -> ClaudeCredentials {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else {
            throw CredentialsError.notFound
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw CredentialsError.unreadable
        }
        return try ClaudeCredentials(json: data)
    }
}
```

- [ ] **Step 2: Verify it builds and existing tests still pass**

Run: `swift test`
Expected: PASS (no new tests; build succeeds)

- [ ] **Step 3: Commit**

```bash
git add Sources/AIStatusKit/Providers/KeychainClaudeCredentialsReader.swift
git commit -m "feat: add Keychain reader for Claude Code credentials"
```

---

### Task 4: ClaudeUsageProvider

**Files:**
- Create: `Sources/AIStatusKit/Providers/ClaudeUsageProvider.swift`
- Create: `Tests/AIStatusKitTests/ClaudeUsageProviderTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/AIStatusKitTests/ClaudeUsageProviderTests.swift`:

```swift
import Foundation
import Testing
@testable import AIStatusKit

struct StubCredentialsReader: ClaudeCredentialsReading {
    let result: Result<ClaudeCredentials, CredentialsError>

    func readCredentials() throws -> ClaudeCredentials {
        try result.get()
    }
}

@Suite("Claude Usage Provider")
struct ClaudeUsageProviderTests {
    let validCredentials = ClaudeCredentials(accessToken: "token", expiresAt: Date(timeIntervalSinceNow: 3600))

    @Test func `fetches usage snapshot on success`() async throws {
        let json = """
        { "five_hour": { "utilization": 42, "resets_at": "2026-07-08T15:00:00Z" }, "seven_day": { "utilization": 61 } }
        """.data(using: .utf8)!
        let provider = ClaudeUsageProvider(
            credentialsReader: StubCredentialsReader(result: .success(validCredentials)),
            session: .mock(data: json)
        )
        let snapshot = try await provider.fetchUsage()
        #expect(snapshot.sessionUtilization == 42)
        #expect(snapshot.weeklyUtilization == 61)
    }

    @Test func `missing credentials throws noCredentials`() async {
        let provider = ClaudeUsageProvider(
            credentialsReader: StubCredentialsReader(result: .failure(.notFound)),
            session: .mock()
        )
        await #expect(throws: UsageError.noCredentials) {
            try await provider.fetchUsage()
        }
    }

    @Test func `unreadable credentials throws noCredentials`() async {
        let provider = ClaudeUsageProvider(
            credentialsReader: StubCredentialsReader(result: .failure(.unreadable)),
            session: .mock()
        )
        await #expect(throws: UsageError.noCredentials) {
            try await provider.fetchUsage()
        }
    }

    @Test func `locally expired token throws tokenExpired without network call`() async {
        let expired = ClaudeCredentials(accessToken: "token", expiresAt: Date(timeIntervalSinceNow: -60))
        let provider = ClaudeUsageProvider(
            credentialsReader: StubCredentialsReader(result: .success(expired)),
            session: .mock(error: URLError(.notConnectedToInternet))
        )
        await #expect(throws: UsageError.tokenExpired) {
            try await provider.fetchUsage()
        }
    }

    @Test func `401 throws tokenExpired`() async {
        let provider = ClaudeUsageProvider(
            credentialsReader: StubCredentialsReader(result: .success(validCredentials)),
            session: .mock(data: Data(), statusCode: 401)
        )
        await #expect(throws: UsageError.tokenExpired) {
            try await provider.fetchUsage()
        }
    }

    @Test func `429 throws rateLimited`() async {
        let provider = ClaudeUsageProvider(
            credentialsReader: StubCredentialsReader(result: .success(validCredentials)),
            session: .mock(data: Data(), statusCode: 429)
        )
        await #expect(throws: UsageError.rateLimited) {
            try await provider.fetchUsage()
        }
    }

    @Test func `server error throws network`() async {
        let provider = ClaudeUsageProvider(
            credentialsReader: StubCredentialsReader(result: .success(validCredentials)),
            session: .mock(data: Data(), statusCode: 500)
        )
        await #expect(throws: UsageError.network) {
            try await provider.fetchUsage()
        }
    }

    @Test func `connection failure throws network`() async {
        let provider = ClaudeUsageProvider(
            credentialsReader: StubCredentialsReader(result: .success(validCredentials)),
            session: .mock(error: URLError(.notConnectedToInternet))
        )
        await #expect(throws: UsageError.network) {
            try await provider.fetchUsage()
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: compile FAILURE — `cannot find 'ClaudeUsageProvider' in scope`

- [ ] **Step 3: Write the implementation**

Create `Sources/AIStatusKit/Providers/ClaudeUsageProvider.swift`:

```swift
import Foundation

public enum UsageError: Error, Equatable {
    case noCredentials
    case tokenExpired
    case rateLimited
    case network
}

public protocol UsageProviding: Sendable {
    func fetchUsage() async throws -> UsageSnapshot
}

public struct ClaudeUsageProvider: UsageProviding {
    static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    static let betaHeader = "oauth-2025-04-20"
    /// Required — without a claude-code User-Agent the endpoint 429s persistently.
    static let userAgent = "claude-code/2.0.0"

    private let credentialsReader: any ClaudeCredentialsReading
    private let session: URLSession

    public init(
        credentialsReader: any ClaudeCredentialsReading = KeychainClaudeCredentialsReader(),
        session: URLSession = .shared
    ) {
        self.credentialsReader = credentialsReader
        self.session = session
    }

    public func fetchUsage() async throws -> UsageSnapshot {
        let credentials: ClaudeCredentials
        do {
            credentials = try credentialsReader.readCredentials()
        } catch {
            throw UsageError.noCredentials
        }
        if let expiresAt = credentials.expiresAt, expiresAt <= Date() {
            throw UsageError.tokenExpired
        }

        var request = URLRequest(url: Self.usageURL)
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw UsageError.network
        }

        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200..<300: break
            case 401, 403: throw UsageError.tokenExpired
            case 429: throw UsageError.rateLimited
            default: throw UsageError.network
            }
        }

        guard let snapshot = try? UsageSnapshot(data: data) else {
            throw UsageError.network
        }
        return snapshot
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/AIStatusKit/Providers/ClaudeUsageProvider.swift Tests/AIStatusKitTests/ClaudeUsageProviderTests.swift
git commit -m "feat: add ClaudeUsageProvider for the OAuth usage endpoint"
```

---

### Task 5: UsageMonitor

**Files:**
- Create: `Sources/AIStatusKit/UsageMonitor.swift`
- Create: `Tests/AIStatusKitTests/UsageMonitorTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/AIStatusKitTests/UsageMonitorTests.swift`:

```swift
import Foundation
import Synchronization
import Testing
@testable import AIStatusKit

/// Returns queued results in order; throws `.network` when exhausted.
final class MockUsageProvider: UsageProviding, Sendable {
    private let results: Mutex<[Result<UsageSnapshot, UsageError>]>

    init(results: [Result<UsageSnapshot, UsageError>]) {
        self.results = Mutex(results)
    }

    func fetchUsage() async throws -> UsageSnapshot {
        let next = results.withLock { $0.isEmpty ? nil : $0.removeFirst() }
        guard let next else { throw UsageError.network }
        return try next.get()
    }
}

@Suite("Usage Monitor")
@MainActor
struct UsageMonitorTests {
    let snapshot = UsageSnapshot(sessionUtilization: 42, sessionResetsAt: nil, weeklyUtilization: 61, weeklyResetsAt: nil)

    @Test func `successful fetch yields available`() async {
        let monitor = UsageMonitor(provider: MockUsageProvider(results: [.success(snapshot)]), autoStart: false)
        await monitor.refresh()
        #expect(monitor.state == .available(snapshot))
    }

    @Test func `initial state is unavailable`() {
        let monitor = UsageMonitor(provider: MockUsageProvider(results: []), autoStart: false)
        #expect(monitor.state == .unavailable)
    }

    @Test func `failure after success yields stale with last snapshot`() async {
        let monitor = UsageMonitor(
            provider: MockUsageProvider(results: [.success(snapshot), .failure(.network)]),
            autoStart: false
        )
        await monitor.refresh()
        await monitor.refresh()
        #expect(monitor.state == .stale(snapshot))
    }

    @Test func `failure without prior data yields unavailable`() async {
        let monitor = UsageMonitor(provider: MockUsageProvider(results: [.failure(.network)]), autoStart: false)
        await monitor.refresh()
        #expect(monitor.state == .unavailable)
    }

    @Test func `missing credentials yields noCredentials`() async {
        let monitor = UsageMonitor(provider: MockUsageProvider(results: [.failure(.noCredentials)]), autoStart: false)
        await monitor.refresh()
        #expect(monitor.state == .noCredentials)
    }

    @Test func `expired token yields tokenExpired`() async {
        let monitor = UsageMonitor(provider: MockUsageProvider(results: [.failure(.tokenExpired)]), autoStart: false)
        await monitor.refresh()
        #expect(monitor.state == .tokenExpired)
    }

    @Test func `rate limit keeps previous state and enables backoff`() async {
        let monitor = UsageMonitor(
            provider: MockUsageProvider(results: [.success(snapshot), .failure(.rateLimited)]),
            autoStart: false
        )
        await monitor.refresh()
        await monitor.refresh()
        #expect(monitor.state == .available(snapshot))
        #expect(monitor.isRateLimited == true)
    }

    @Test func `success clears rate limit backoff`() async {
        let monitor = UsageMonitor(
            provider: MockUsageProvider(results: [.failure(.rateLimited), .success(snapshot)]),
            autoStart: false
        )
        await monitor.refresh()
        await monitor.refresh()
        #expect(monitor.state == .available(snapshot))
        #expect(monitor.isRateLimited == false)
    }

    @Test func `displayedSnapshot exposes available and stale values only`() {
        #expect(UsageMonitor.State.available(snapshot).displayedSnapshot == snapshot)
        #expect(UsageMonitor.State.stale(snapshot).displayedSnapshot == snapshot)
        #expect(UsageMonitor.State.unavailable.displayedSnapshot == nil)
        #expect(UsageMonitor.State.noCredentials.displayedSnapshot == nil)
        #expect(UsageMonitor.State.tokenExpired.displayedSnapshot == nil)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: compile FAILURE — `cannot find 'UsageMonitor' in scope`

- [ ] **Step 3: Write the implementation**

Create `Sources/AIStatusKit/UsageMonitor.swift`:

```swift
import Foundation
import Observation

@Observable
@MainActor
public final class UsageMonitor {
    public enum State: Equatable {
        case unavailable
        case noCredentials
        case tokenExpired
        case available(UsageSnapshot)
        case stale(UsageSnapshot)

        public var displayedSnapshot: UsageSnapshot? {
            switch self {
            case let .available(snapshot), let .stale(snapshot): snapshot
            case .unavailable, .noCredentials, .tokenExpired: nil
            }
        }
    }

    public private(set) var state: State = .unavailable
    private(set) var isRateLimited = false

    private let provider: any UsageProviding
    private let interval: TimeInterval
    private let backoffInterval: TimeInterval
    private var task: Task<Void, Never>?

    public init(
        provider: any UsageProviding,
        interval: TimeInterval = 180,
        backoffInterval: TimeInterval = 600,
        autoStart: Bool = true
    ) {
        self.provider = provider
        self.interval = interval
        self.backoffInterval = backoffInterval

        if autoStart {
            startMonitoring()
        }
    }

    public func refresh() async {
        do {
            state = .available(try await provider.fetchUsage())
            isRateLimited = false
        } catch UsageError.noCredentials {
            state = .noCredentials
        } catch UsageError.tokenExpired {
            state = .tokenExpired
        } catch UsageError.rateLimited {
            isRateLimited = true
        } catch {
            if let snapshot = state.displayedSnapshot {
                state = .stale(snapshot)
            } else {
                state = .unavailable
            }
        }
    }

    public func startMonitoring() {
        guard task == nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(isRateLimited ? backoffInterval : interval))
            }
        }
    }

    public func stopMonitoring() {
        task?.cancel()
        task = nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/AIStatusKit/UsageMonitor.swift Tests/AIStatusKitTests/UsageMonitorTests.swift
git commit -m "feat: add UsageMonitor with polling and rate-limit backoff"
```

---

### Task 6: Reset time formatting

**Files:**
- Create: `Sources/AIStatusKit/UsageResetFormat.swift`
- Create: `Tests/AIStatusKitTests/UsageResetFormatTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/AIStatusKitTests/UsageResetFormatTests.swift`:

```swift
import Foundation
import Testing
@testable import AIStatusKit

@Suite("Usage Reset Format")
struct UsageResetFormatTests {
    var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    let locale = Locale(identifier: "en_US")

    @Test func `same-day reset formats as time`() {
        let now = ISO8601DateFormatter().date(from: "2026-07-08T10:00:00Z")!
        let reset = ISO8601DateFormatter().date(from: "2026-07-08T15:00:00Z")!
        let result = UsageResetFormat.string(for: reset, relativeTo: now, calendar: utcCalendar, locale: locale)
        #expect(result.contains("3:00"))
    }

    @Test func `other-day reset formats as weekday`() {
        let now = ISO8601DateFormatter().date(from: "2026-07-08T10:00:00Z")!
        let reset = ISO8601DateFormatter().date(from: "2026-07-14T00:00:00Z")!
        let result = UsageResetFormat.string(for: reset, relativeTo: now, calendar: utcCalendar, locale: locale)
        #expect(result == "Tue")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: compile FAILURE — `cannot find 'UsageResetFormat' in scope`

- [ ] **Step 3: Write the implementation**

Create `Sources/AIStatusKit/UsageResetFormat.swift`:

```swift
import Foundation

/// Formats a usage-window reset date: same-day → time ("3:00 PM"), otherwise weekday ("Tue").
public enum UsageResetFormat {
    public static func string(
        for date: Date,
        relativeTo now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            date.formatted(
                Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            )
        } else {
            date.formatted(
                Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).weekday(.abbreviated)
            )
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/AIStatusKit/UsageResetFormat.swift Tests/AIStatusKitTests/UsageResetFormatTests.swift
git commit -m "feat: add reset time formatting for usage windows"
```

---

### Task 7: Menu bar UI

**Files:**
- Create: `Sources/AIStatusBar/UsageSection.swift`
- Modify: `Sources/AIStatusBar/StatusMenuContent.swift`
- Modify: `Sources/AIStatusBar/AIStatusBarApp.swift`

No unit tests — SwiftUI menu content; verified by build + manual run.

- [ ] **Step 1: Create the usage section view**

Create `Sources/AIStatusBar/UsageSection.swift`:

```swift
import SwiftUI
import AIStatusKit

struct UsageSection: View {
    let monitor: UsageMonitor

    var body: some View {
        Group {
            switch monitor.state {
            case .noCredentials:
                Text("Install Claude Code and sign in to see usage")
            case .tokenExpired:
                Text("Run claude in a terminal to refresh usage")
            case .unavailable:
                Text("Claude usage unavailable")
            case let .available(snapshot):
                Text("Claude Usage")
                rows(for: snapshot)
            case let .stale(snapshot):
                Text("Claude Usage (last known)")
                rows(for: snapshot)
            }
        }
        .onAppear {
            Task { await monitor.refresh() }
        }
    }

    @ViewBuilder
    private func rows(for snapshot: UsageSnapshot) -> some View {
        if let session = snapshot.sessionUtilization {
            Text(rowText(label: "Session (5h)", percent: session, resetsAt: snapshot.sessionResetsAt))
        }
        if let weekly = snapshot.weeklyUtilization {
            Text(rowText(label: "Week", percent: weekly, resetsAt: snapshot.weeklyResetsAt))
        }
    }

    private func rowText(label: String, percent: Int, resetsAt: Date?) -> String {
        var text = "\(label): \(percent)%"
        if let resetsAt {
            text += " · resets \(UsageResetFormat.string(for: resetsAt))"
        }
        return text
    }
}
```

- [ ] **Step 2: Add the section to the menu**

Modify `Sources/AIStatusBar/StatusMenuContent.swift` — add the `usageMonitor` property and insert the usage section between the provider list and Quit:

```swift
import SwiftUI
import AIStatusKit

struct StatusMenuContent: View {
    let monitor: StatusMonitor
    let usageMonitor: UsageMonitor

    var body: some View {
        ForEach(Array(monitor.providers), id: \.name) { provider in
            let status = monitor.statuses[provider.name] ?? .unknown
            let isSelected = provider.name == monitor.selectedProvider.name

            Toggle(isOn: Binding(
                get: { isSelected },
                set: { _ in monitor.selectedProvider = provider }
            )) {
                Label {
                    Text(provider.name)
                } icon: {
                    Image(status.dotImageName, bundle: .module)
                        .renderingMode(.original)
                }
            }
        }

        Divider()

        UsageSection(monitor: usageMonitor)

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
```

- [ ] **Step 3: Add the usage monitor and percentage label to the app**

Modify `Sources/AIStatusBar/AIStatusBarApp.swift`:

```swift
import SwiftUI
import AIStatusKit

@main
struct AIStatusBarApp: App {
    @State private var monitor = StatusMonitor(providers: AI.all)
    @State private var usageMonitor = UsageMonitor(provider: ClaudeUsageProvider())

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            StatusMenuContent(monitor: monitor, usageMonitor: usageMonitor)
        } label: {
            HStack(spacing: 4) {
                Image(monitor.selectedStatus.dotImageName, bundle: .module)
                    .renderingMode(.original)
                if let percent = usageMonitor.state.displayedSnapshot?.limitingUtilization {
                    Text("\(percent)%")
                }
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
```

- [ ] **Step 4: Build and run the full test suite**

Run: `swift test && swift build`
Expected: tests PASS, build succeeds

- [ ] **Step 5: Manual verification**

Run: `swift run AIStatusBar`

Verify:
1. macOS shows a Keychain permission dialog for "Claude Code-credentials" on first fetch — click **Always Allow**.
2. Within a few seconds the menu bar shows the dot followed by a percentage (e.g. `● 61%`).
3. Open the menu: "Claude Usage" section shows `Session (5h): X% · resets …` and `Week: Y% · resets …` rows matching what `claude` → `/usage` reports.
4. Provider selection and Quit still work.
5. If the `.onAppear` refresh does not fire in `.menu` style (rows never update on open), note it — polling still updates every 180s, but record the limitation for follow-up.

- [ ] **Step 6: Commit**

```bash
git add Sources/AIStatusBar
git commit -m "feat: show Claude usage in menu bar label and dropdown"
```

---

### Task 8: README update and wrap-up

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Document the feature in README**

In `README.md`, replace the Menu Bar App bullet in the "What is it?" section:

```markdown
- **Menu Bar App** — A colored dot that stays in your menu bar. Pick which service to watch — Green = all good, orange = degraded, red = outage, gray = unknown. If you use Claude Code, it also shows your live Claude plan usage (session and weekly %) right in the menu bar.
```

And add a new section after "Supported Services":

```markdown
## Claude Usage

The menu bar app can display your personal Claude plan usage — the same 5-hour session % and weekly % that Claude Code's `/usage` command shows. The number next to the dot is whichever limit you'll hit first.

Requirements:

- [Claude Code](https://claude.com/claude-code) installed and signed in (the app reuses its credentials from the macOS Keychain — you'll be asked to allow access once)

If Claude Code isn't installed, the app simply shows the status dot as before.
```

- [ ] **Step 2: Run the full suite one last time**

Run: `swift test && swift build`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: document Claude usage feature in README"
```

---

## Verification Checklist (post-implementation)

- [ ] `swift test` passes with all new suites green
- [ ] `swift run AIStatusBar` shows `● N%` in the menu bar within seconds
- [ ] Dropdown rows match `claude` → `/usage` values
- [ ] With Wi-Fi off after a successful fetch, menu shows "(last known)" header and label keeps the last %
- [ ] Use superpowers:finishing-a-development-branch to merge/PR `feat/claude-usage`

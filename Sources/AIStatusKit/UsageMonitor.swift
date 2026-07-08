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
    private var isRefreshing = false

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
        // The polling loop and the menu-open refresh both call this; a single
        // in-flight fetch is enough, and the usage endpoint is rate-limit sensitive.
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
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

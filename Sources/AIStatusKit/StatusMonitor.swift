import Foundation
import Observation

@Observable
@MainActor
public final class StatusMonitor {
    public private(set) var statuses: [String: AIStatus] = [:]
    private let providers: [any StatusProvider]
    private let interval: TimeInterval
    private var task: Task<Void, Never>?

    public var overallStatus: AIStatus {
        AIStatus.worst(Array(statuses.values))
    }

    public init(providers: [any StatusProvider], interval: TimeInterval = 30) {
        self.providers = providers
        self.interval = interval
        startMonitoring()
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

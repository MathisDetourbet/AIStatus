import Foundation
import Observation

@Observable
@MainActor
public final class StatusMonitor {
    public private(set) var statuses: [String: ServiceStatus] = [:]
    private let providers: [any StatusProvider]
    private let interval: TimeInterval
    private var task: Task<Void, Never>?

    public var overallStatus: ServiceStatus {
        ServiceStatus.worst(Array(statuses.values))
    }

    public init(providers: [any StatusProvider], interval: TimeInterval = 60) {
        self.providers = providers
        self.interval = interval
    }

    public func refresh() async {
        await withTaskGroup(of: (String, ServiceStatus).self) { group in
            for provider in providers {
                group.addTask {
                    let status = (try? await provider.fetchStatus()) ?? .unknown
                    return (provider.name, status)
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

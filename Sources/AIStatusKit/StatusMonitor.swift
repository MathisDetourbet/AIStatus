import Foundation
import NonEmpty
import Observation

@Observable
@MainActor
public final class StatusMonitor {
    private static let selectedProviderKey = "selectedProvider"

    public private(set) var statuses: [String: AIStatus] = [:]
    public let providers: NonEmptyArray<any StatusProvider>
    private let interval: TimeInterval
    private var task: Task<Void, Never>?
    private let defaults: UserDefaults

    public var selectedProvider: any StatusProvider {
        didSet {
            defaults.set(selectedProvider.name, forKey: Self.selectedProviderKey)
        }
    }

    public var overallStatus: AIStatus {
        AIStatus.worst(Array(statuses.values))
    }

    public var selectedStatus: AIStatus {
        statuses[selectedProvider.name] ?? .unknown
    }

    public init(
        providers: NonEmptyArray<any StatusProvider>,
        interval: TimeInterval = 30,
        defaults: UserDefaults = .aiStatus
    ) {
        self.providers = providers
        self.interval = interval
        self.defaults = defaults

        let savedName = defaults.string(forKey: Self.selectedProviderKey)
        self.selectedProvider = providers.first { $0.name == savedName } ?? providers.first

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

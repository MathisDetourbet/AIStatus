import SwiftUI

public enum ServiceStatus: Comparable, Sendable {
    case operational
    case minor
    case major
    case unknown

    public var isHealthy: Bool {
        self == .operational
    }

    public var color: Color {
        switch self {
        case .operational: .green
        case .minor: .orange
        case .major: .red
        case .unknown: .gray
        }
    }

    public static func worst(_ statuses: [ServiceStatus]) -> ServiceStatus {
        statuses.max() ?? .unknown
    }
}

extension ServiceStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .operational: "operational"
        case .minor: "degraded"
        case .major: "major outage"
        case .unknown: "unknown"
        }
    }
}

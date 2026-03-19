import SwiftUI

public enum AIStatus: Comparable, Sendable {
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

    public var dotImageName: String {
        switch self {
        case .operational: "dot-operational"
        case .minor: "dot-degraded"
        case .major: "dot-outage"
        case .unknown: "dot-unknown"
        }
    }

    public static func worst(_ statuses: [AIStatus]) -> AIStatus {
        statuses.max() ?? .unknown
    }
}

extension AIStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .operational: "operational"
        case .minor: "degraded"
        case .major: "major outage"
        case .unknown: "unknown"
        }
    }
}

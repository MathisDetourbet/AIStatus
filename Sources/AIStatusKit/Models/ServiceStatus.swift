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

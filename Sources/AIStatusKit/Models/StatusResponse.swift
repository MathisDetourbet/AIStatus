import Foundation

public struct StatusResponse: Decodable, Sendable {
    public let status: Status

    public struct Status: Decodable, Sendable {
        public let indicator: String
        public let description: String
    }

    public static func mapIndicator(_ indicator: String) -> AIStatus {
        switch indicator {
        case "none": .operational
        case "minor": .minor
        case "major", "critical": .major
        default: .unknown
        }
    }
}

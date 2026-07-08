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
            sessionUtilization: response.fiveHour?.utilization.flatMap { Int(exactly: $0.rounded()) },
            sessionResetsAt: response.fiveHour?.resetsAt,
            weeklyUtilization: response.sevenDay?.utilization.flatMap { Int(exactly: $0.rounded()) },
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

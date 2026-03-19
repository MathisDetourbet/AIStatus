import Foundation

public enum AI {
    public static let claude = StatuspageProvider(
        name: "Claude",
        baseURL: URL(string: "https://status.claude.com")!
    )

    public static let all: [any StatusProvider] = [claude]
}

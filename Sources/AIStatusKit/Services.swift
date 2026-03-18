import Foundation

public enum Services {
    public static let claude = StatuspageProvider(
        name: "Claude",
        baseURL: URL(string: "https://status.claude.com")!
    )

    public static let all: [any StatusProvider] = [claude]
}

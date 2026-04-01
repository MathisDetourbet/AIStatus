import Foundation
import NonEmpty

public enum AI {
    public static let claude = StatuspageProvider(
        name: "Claude",
        baseURL: URL(string: "https://status.claude.com")!
    )

    public static let openai = StatuspageProvider(
        name: "OpenAI",
        baseURL: URL(string: "https://status.openai.com")!
    )

    public static let cursor = StatuspageProvider(
        name: "Cursor",
        baseURL: URL(string: "https://status.cursor.com")!
    )

    public static let all: NonEmptyArray<any StatusProvider> = NonEmptyArray(rawValue: [claude, openai, cursor])!
}

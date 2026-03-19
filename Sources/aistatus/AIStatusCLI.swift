import Foundation
import AIStatusKit

@main
struct AIStatusCLI {
    static func main() async {
        let providers = AI.all
        var exitCode: Int32 = 0

        for provider in providers {
            do {
                let status = try await provider.fetchStatus()
                let symbol: String
                let color: String
                switch status {
                case .operational:
                    symbol = "✓"
                    color = "\u{001B}[32m"
                case .minor:
                    symbol = "⚠"
                    color = "\u{001B}[33m"
                    exitCode = max(exitCode, 1)
                case .major:
                    symbol = "✗"
                    color = "\u{001B}[31m"
                    exitCode = max(exitCode, 1)
                case .unknown:
                    symbol = "?"
                    color = "\u{001B}[90m"
                    exitCode = max(exitCode, 2)
                }
                let reset = "\u{001B}[0m"
                print("\(color)\(symbol) \(provider.name): \(status)\(reset)")
            } catch {
                let gray = "\u{001B}[90m"
                let reset = "\u{001B}[0m"
                print("\(gray)? \(provider.name): error - \(error.localizedDescription)\(reset)")
                exitCode = max(exitCode, 2)
            }
        }

        Darwin.exit(exitCode)
    }
}

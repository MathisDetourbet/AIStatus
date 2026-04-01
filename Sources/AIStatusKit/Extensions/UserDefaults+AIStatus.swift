import Foundation

extension UserDefaults {
    public nonisolated(unsafe) static let aiStatus = UserDefaults(suiteName: "com.aistatusbar.app")!
}

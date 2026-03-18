import SwiftUI
import AIStatusKit

@main
struct AIStatusBarApp: App {
    var body: some Scene {
        MenuBarExtra("AIStatus", systemImage: "circle.fill") {
            Text("Loading...")
        }
    }
}

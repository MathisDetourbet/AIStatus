import SwiftUI
import AIStatusKit

@main
struct AIStatusBarApp: App {
    @State private var monitor = StatusMonitor(providers: AI.all)

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            StatusMenuContent(monitor: monitor)
        } label: {
            Image(monitor.overallStatus.dotImageName, bundle: .module)
                .renderingMode(.original)
        }
        .menuBarExtraStyle(.menu)
    }
}

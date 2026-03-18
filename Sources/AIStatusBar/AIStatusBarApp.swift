import SwiftUI
import AppKit
import AIStatusKit

@main
struct AIStatusBarApp: App {
    @State private var monitor = StatusMonitor(providers: Services.all)

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            Image(systemName: "circle.fill")
                .foregroundStyle(monitor.overallStatus.color)
                .task { monitor.startMonitoring() }
        }
        .menuBarExtraStyle(.menu)
    }
}

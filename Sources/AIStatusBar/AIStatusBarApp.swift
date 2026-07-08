import SwiftUI
import AIStatusKit

@main
struct AIStatusBarApp: App {
    @State private var monitor = StatusMonitor(providers: AI.all)
    @State private var usageMonitor = UsageMonitor(provider: ClaudeUsageProvider())

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            StatusMenuContent(monitor: monitor, usageMonitor: usageMonitor)
        } label: {
            HStack(spacing: 4) {
                Image(monitor.selectedStatus.dotImageName, bundle: .module)
                    .renderingMode(.original)
                if let percent = usageMonitor.state.displayedSnapshot?.limitingUtilization {
                    Text("\(percent)%")
                }
            }
        }
        .menuBarExtraStyle(.menu)
    }
}

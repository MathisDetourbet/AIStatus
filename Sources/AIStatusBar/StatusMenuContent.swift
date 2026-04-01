import SwiftUI
import AIStatusKit

struct StatusMenuContent: View {
    let monitor: StatusMonitor

    var body: some View {
        ForEach(Array(monitor.providers), id: \.name) { provider in
            let status = monitor.statuses[provider.name] ?? .unknown
            let isSelected = provider.name == monitor.selectedProvider.name

            Toggle(isOn: Binding(
                get: { isSelected },
                set: { _ in monitor.selectedProvider = provider }
            )) {
                Label {
                    Text(provider.name)
                } icon: {
                    Image(status.dotImageName, bundle: .module)
                        .renderingMode(.original)
                }
            }
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

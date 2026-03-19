import SwiftUI
import AIStatusKit

struct StatusMenuContent: View {
    let monitor: StatusMonitor

    var body: some View {
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

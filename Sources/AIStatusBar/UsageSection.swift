import SwiftUI
import AIStatusKit

struct UsageSection: View {
    let monitor: UsageMonitor

    var body: some View {
        Group {
            switch monitor.state {
            case .noCredentials:
                Text("Install Claude Code and sign in to see usage")
            case .tokenExpired:
                Text("Run claude in a terminal to refresh usage")
            case .unavailable:
                Text("Claude usage unavailable")
            case let .available(snapshot):
                Text("Claude Usage")
                rows(for: snapshot)
            case let .stale(snapshot):
                Text("Claude Usage (last known)")
                rows(for: snapshot)
            }
        }
        .onAppear {
            Task { await monitor.refresh() }
        }
    }

    @ViewBuilder
    private func rows(for snapshot: UsageSnapshot) -> some View {
        if let session = snapshot.sessionUtilization {
            Text(rowText(label: "Session (5h)", percent: session, resetsAt: snapshot.sessionResetsAt))
        }
        if let weekly = snapshot.weeklyUtilization {
            Text(rowText(label: "Week", percent: weekly, resetsAt: snapshot.weeklyResetsAt))
        }
    }

    private func rowText(label: String, percent: Int, resetsAt: Date?) -> String {
        var text = "\(label): \(percent)%"
        if let resetsAt {
            text += " · resets \(UsageResetFormat.string(for: resetsAt))"
        }
        return text
    }
}

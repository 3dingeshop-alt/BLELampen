import WidgetKit
import SwiftUI
import ActivityKit

@main
struct BLELampenWidgetBundle: WidgetBundle {
    var body: some Widget {
        BLELampenLiveActivity()
    }
}

/// Zeigt die Dynamic Island (iPhone 14 Pro und neuer) bzw. das Live-Activity-Banner auf dem
/// Sperrbildschirm, solange die App mit mindestens einer Lampe verbunden ist.
struct BLELampenLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BLELampenActivityAttributes.self) { context in
            // Sperrbildschirm / Banner-Ansicht
            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("BLE Lampen")
                        .font(.headline)
                    Text(statusText(context.state))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.85))
            .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.connectedCount)")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(statusText(context.state))
                        .font(.caption)
                }
            } compactLeading: {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
            } compactTrailing: {
                Text("\(context.state.connectedCount)")
            } minimal: {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
            }
        }
    }

    private func statusText(_ state: BLELampenActivityAttributes.ContentState) -> String {
        if let sceneName = state.sceneName {
            return "Szene: \(sceneName)"
        }
        return "\(state.connectedCount) Lampe(n) verbunden"
    }
}

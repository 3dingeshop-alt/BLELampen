import Foundation
import ActivityKit
import Combine

/// Startet/aktualisiert die Dynamic-Island- bzw. Sperrbildschirm-Live-Activity, solange
/// mindestens eine Lampe verbunden ist, und beendet sie wieder, sobald keine mehr verbunden
/// ist. Läuft automatisch im Hintergrund mit, ohne dass man etwas antippen muss.
@available(iOS 16.2, *)
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activity: Activity<BLELampenActivityAttributes>?
    private var cancellable: AnyCancellable?

    private init() {}

    func start() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        cancellable = Publishers.CombineLatest(
            LightingEnvironment.bt.$connectedDevices,
            LightingEnvironment.effects.$activeSceneName
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] devices, sceneName in
            self?.apply(count: devices.count, sceneName: sceneName)
        }
    }

    private func apply(count: Int, sceneName: String?) {
        let state = BLELampenActivityAttributes.ContentState(connectedCount: count, sceneName: sceneName)

        if let activity {
            Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
            if count == 0 {
                Task { await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(.now + 5)) }
                self.activity = nil
            }
        } else if count > 0 {
            do {
                let content = ActivityContent(state: state, staleDate: nil)
                activity = try Activity.request(attributes: BLELampenActivityAttributes(), content: content)
            } catch {
                print("Live Activity konnte nicht gestartet werden: \(error)")
            }
        }
    }
}

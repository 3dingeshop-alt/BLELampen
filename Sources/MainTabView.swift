import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var bt: BluetoothManager
    @EnvironmentObject var effects: EffectEngine
    @EnvironmentObject var scenes: SceneStore
    @EnvironmentObject var schedules: ScheduleStore

    var body: some View {
        TabView {
            ContentView()
                .tabItem { Label("Geräte", systemImage: "antenna.radiowaves.left.and.right") }

            ScenesView(sceneStore: scenes, effectEngine: effects)
                .tabItem { Label("Szenen", systemImage: "sparkles") }

            SchedulesView(scheduleStore: schedules, sceneStore: scenes)
                .tabItem { Label("Zeitpläne", systemImage: "clock") }

            MusicSyncView()
                .tabItem { Label("Musik", systemImage: "music.note") }
        }
    }
}

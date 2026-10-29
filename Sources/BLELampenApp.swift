import SwiftUI

@main
struct BLELampenApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(LightingEnvironment.bt)
                .environmentObject(LightingEnvironment.effects)
                .environmentObject(LightingEnvironment.scenes)
                .environmentObject(LightingEnvironment.schedules)
                .onAppear {
                    ScheduleRunner.shared.start()
                    if #available(iOS 16.2, *) {
                        LiveActivityManager.shared.start()
                    }
                }
        }
    }
}

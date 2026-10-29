import Foundation

/// Geteilte Instanzen, die sowohl von der normalen App-Oberfläche (SwiftUI-Views) als
/// auch von Siri/Kurzbefehlen (App Intents, die unabhängig von der View-Hierarchie
/// ausgeführt werden) benutzt werden. Wichtig: nur EINE BluetoothManager-Instanz pro App-
/// Prozess, sonst würde Siri eine "leere", nie verbundene Kopie steuern.
enum LightingEnvironment {
    static let bt = BluetoothManager.shared
    static let effects = EffectEngine()
    static let scenes = SceneStore()
    static let schedules = ScheduleStore()
}

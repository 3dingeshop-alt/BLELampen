import ActivityKit

/// Wird von der App UND der Widget-Erweiterung benutzt (deshalb im "Shared"-Ordner, der in
/// beide Xcode-Targets eingebunden ist). Beschreibt, was die Dynamic Island / das Sperrbildschirm-
/// Live-Activity-Banner anzeigt, solange Lampen verbunden sind.
struct BLELampenActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Anzahl aktuell verbundener LED-Controller.
        var connectedCount: Int
        /// Name der gerade laufenden Szene/des Effekts, falls einer aktiv ist.
        var sceneName: String?
    }
}

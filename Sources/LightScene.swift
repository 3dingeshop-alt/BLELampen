import Foundation

/// Ein animierter Lichteffekt, der auf allen ausgewählten Geräten läuft, bis er gestoppt wird.
enum LightEffect: String, CaseIterable, Identifiable, Codable {
    case rainbow = "Regenbogen"
    case colorFade = "Farbwechsel"
    case breathe = "Atmen"
    case strobe = "Blitz"
    case candle = "Kerzenflackern"
    case halloween = "Halloween"
    case christmas = "Weihnachten"

    var id: String { rawValue }

    /// Schrittabstand bei "normaler" Geschwindigkeit (50%). Wird von LightScene.stepMillis
    /// abhängig vom eingestellten Tempo gestaucht/gestreckt.
    var defaultStepMillis: Int {
        switch self {
        case .rainbow: return 90
        case .colorFade: return 2500
        case .breathe: return 60
        case .strobe: return 150
        case .candle: return 110
        case .halloween: return 70
        case .christmas: return 1200
        }
    }

    var systemImageName: String {
        switch self {
        case .rainbow: return "rainbow"
        case .colorFade: return "paintpalette.fill"
        case .breathe: return "wind"
        case .strobe: return "bolt.fill"
        case .candle: return "flame.fill"
        case .halloween: return "theatermasks.fill"
        case .christmas: return "snowflake"
        }
    }
}

/// Eine gespeicherte Szene: ein Effekt mit Name und Geschwindigkeit, den man per Tap
/// (oder per Siri/Kurzbefehl) auf die ausgewählten Geräte loslassen kann.
struct LightScene: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var effect: LightEffect
    var speedPercent: Double // 0...100, 50 = effect.defaultStepMillis

    init(id: UUID = UUID(), name: String, effect: LightEffect, speedPercent: Double = 50) {
        self.id = id
        self.name = name
        self.effect = effect
        self.speedPercent = speedPercent
    }

    /// Effektiver Schrittabstand in Millisekunden abhängig von der Geschwindigkeit
    /// (höherer Prozentwert = schneller, mindestens 20ms zum Schutz vor BLE-Überlastung).
    var stepMillis: Int {
        let factor = max(0.2, 2.0 - (speedPercent / 100.0) * 1.8)
        return max(20, Int(Double(effect.defaultStepMillis) * factor))
    }
}

/// Persistiert die gespeicherten Szenen/Effekte des Nutzers in UserDefaults.
final class SceneStore: ObservableObject {
    @Published var scenes: [LightScene] {
        didSet { save() }
    }

    private let key = "led_scenes_v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([LightScene].self, from: data) {
            scenes = decoded
        } else {
            scenes = SceneStore.defaultScenes
        }
    }

    private static let defaultScenes: [LightScene] = [
        LightScene(name: "Regenbogen", effect: .rainbow, speedPercent: 50),
        LightScene(name: "Gemütlich atmen", effect: .breathe, speedPercent: 30),
        LightScene(name: "Halloween 1", effect: .strobe, speedPercent: 70),
        LightScene(name: "Halloween 2", effect: .halloween, speedPercent: 90),
        LightScene(name: "Kerzenschein", effect: .candle, speedPercent: 40),
        LightScene(name: "Farbwechsel", effect: .colorFade, speedPercent: 40),
        LightScene(name: "Weihnachten", effect: .christmas, speedPercent: 30)
    ]

    private func save() {
        if let data = try? JSONEncoder().encode(scenes) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

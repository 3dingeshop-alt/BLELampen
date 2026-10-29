import Foundation

enum ScheduleTrigger: Codable, Equatable {
    case fixedTime(hour: Int, minute: Int)
    case sunset(offsetMinutes: Int)
    case sunrise(offsetMinutes: Int)
}

enum ScheduleAction: Codable, Equatable {
    case powerOn
    case powerOff
    case scene(name: String)
}

/// Ein einzelner Eintrag im Zeitplan: wann (feste Uhrzeit oder Sonnenauf-/-untergang mit
/// Versatz), an welchen Wochentagen, und was dann passieren soll.
struct LightSchedule: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var trigger: ScheduleTrigger
    var action: ScheduleAction
    var isEnabled: Bool = true
    /// Calendar.weekday: 1 = Sonntag ... 7 = Samstag. Standard: alle Tage.
    var weekdays: Set<Int> = Set(1...7)
}

/// Persistiert die vom Nutzer angelegten Zeitpläne. Dient als Vorlage sowohl für die
/// In-App-Übersicht als auch dafür, dieselben Einträge über eine Kurzbefehle-
/// Automatisierung zuverlässig auch im Hintergrund auszulösen (siehe SchedulesView).
final class ScheduleStore: ObservableObject {
    @Published var schedules: [LightSchedule] {
        didSet { save() }
    }

    private let key = "led_schedules_v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([LightSchedule].self, from: data) {
            schedules = decoded
        } else {
            schedules = []
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(schedules) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

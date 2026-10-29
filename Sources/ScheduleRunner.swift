import Foundation

/// Prüft minütlich, solange die App läuft (vorne oder kurz im Hintergrund), ob ein
/// Zeitplan-Eintrag mit fester Uhrzeit fällig ist, und führt ihn dann aus.
///
/// Wichtig zu wissen: Das ist nur ein Best-Effort-Komfort, kein zuverlässiger Hintergrund-
/// Timer - iOS erlaubt Drittanbieter-Apps keine exakten Hintergrund-Alarme, und Sonnenauf-/
/// -untergang wird hier bewusst NICHT berechnet (das würde ungenau und könnte falsch
/// schalten). Für wirklich zuverlässiges Auslösen auch bei komplett geschlossener App
/// und für exakte Sonnenzeiten: die Kurzbefehle-Automatisierung einrichten (siehe
/// SchedulesView) - die nutzt die eingebaute, exakte Sonnenauf-/-untergangsberechnung
/// von iOS und weckt die App bei Bedarf selbst zuverlässig auf.
final class ScheduleRunner {
    static let shared = ScheduleRunner()

    private var timer: Timer?
    private var lastFiredKey: [UUID: String] = [:]

    private init() {}

    func start() {
        checkDue()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkDue()
        }
    }

    func checkDue() {
        let now = Date()
        let calendar = Calendar.current
        let minuteKey = "\(calendar.component(.dayOfYear, from: now))-\(calendar.component(.hour, from: now)):\(calendar.component(.minute, from: now))"

        for schedule in LightingEnvironment.schedules.schedules where schedule.isEnabled {
            guard case .fixedTime(let hour, let minute) = schedule.trigger else { continue }
            let weekday = calendar.component(.weekday, from: now)
            guard schedule.weekdays.contains(weekday) else { continue }
            let comps = calendar.dateComponents([.hour, .minute], from: now)
            guard comps.hour == hour, comps.minute == minute else { continue }
            guard lastFiredKey[schedule.id] != minuteKey else { continue }
            lastFiredKey[schedule.id] = minuteKey
            run(schedule)
        }
    }

    private func run(_ schedule: LightSchedule) {
        let bt = LightingEnvironment.bt
        switch schedule.action {
        case .powerOn:
            bt.sendToAllConnected { $0.commands.powerOn() }
        case .powerOff:
            bt.sendToAllConnected { $0.commands.powerOff() }
        case .scene(let name):
            guard let scene = LightingEnvironment.scenes.scenes.first(where: { $0.name == name }) else { return }
            let ids = bt.connectedDevices.map { $0.id }
            LightingEnvironment.effects.start(scene: scene, bt: bt, deviceIDs: ids)
        }
    }
}

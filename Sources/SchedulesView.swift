import SwiftUI

struct SchedulesView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @ObservedObject var sceneStore: SceneStore
    @Environment(\.openURL) var openURL
    @State private var showNewSchedule = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Beliebig viele Zeitfenster, nicht nur 2-3 wie bei den Hersteller-Apps. Läuft zuverlässig auch bei geschlossener App und mit exaktem Sonnenauf-/-untergang über die Kurzbefehle-Automatisierung ganz unten - die Einträge hier sind die Vorlage dafür.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Geplante Zeiten") {
                    if scheduleStore.schedules.isEmpty {
                        Text("Noch kein Zeitplan angelegt.").foregroundStyle(.secondary)
                    }
                    ForEach(scheduleStore.schedules) { schedule in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(schedule.name).font(.headline)
                                Spacer()
                                Toggle("", isOn: binding(for: schedule))
                                    .labelsHidden()
                            }
                            Text(describe(schedule))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        scheduleStore.schedules.remove(atOffsets: indexSet)
                    }
                    Button("Zeitplan hinzufügen") { showNewSchedule = true }
                }

                Section("Kurzbefehle-Automatisierung") {
                    Button("Kurzbefehle-App öffnen") {
                        if let url = URL(string: "shortcuts://create-automation") {
                            openURL(url)
                        }
                    }
                    Text("Dort: Automatisierung → Tageszeit (oder Sonnenuntergang/-aufgang) → als Aktion \"BLE Lampen\" suchen und den passenden Kurzbefehl wählen (z.B. \"Licht an\", \"Szene Weihnachten starten\"). \"Vor dem Ausführen fragen\" ausschalten, dann läuft es automatisch - auch bei geschlossener App.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Zeitpläne")
            .sheet(isPresented: $showNewSchedule) {
                NewScheduleSheet(scheduleStore: scheduleStore, sceneStore: sceneStore)
            }
        }
    }

    private func binding(for schedule: LightSchedule) -> Binding<Bool> {
        Binding(
            get: { schedule.isEnabled },
            set: { newValue in
                if let index = scheduleStore.schedules.firstIndex(where: { $0.id == schedule.id }) {
                    scheduleStore.schedules[index].isEnabled = newValue
                }
            }
        )
    }

    private func describe(_ schedule: LightSchedule) -> String {
        let triggerText: String
        switch schedule.trigger {
        case .fixedTime(let hour, let minute):
            triggerText = String(format: "täglich um %02d:%02d", hour, minute)
        case .sunset(let offset):
            triggerText = offset == 0 ? "bei Sonnenuntergang" : (offset > 0 ? "\(offset) Min. nach Sonnenuntergang" : "\(-offset) Min. vor Sonnenuntergang")
        case .sunrise(let offset):
            triggerText = offset == 0 ? "bei Sonnenaufgang" : (offset > 0 ? "\(offset) Min. nach Sonnenaufgang" : "\(-offset) Min. vor Sonnenaufgang")
        }
        let actionText: String
        switch schedule.action {
        case .powerOn: actionText = "Licht an"
        case .powerOff: actionText = "Licht aus"
        case .scene(let name): actionText = "Szene \"\(name)\" starten"
        }
        return "\(triggerText) – \(actionText)"
    }
}

struct NewScheduleSheet: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @ObservedObject var sceneStore: SceneStore
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var triggerType = 0 // 0 = Uhrzeit, 1 = Sonnenuntergang, 2 = Sonnenaufgang
    @State private var time = Date()
    @State private var offsetMinutes: Double = 0
    @State private var actionType = 0 // 0 = an, 1 = aus, 2 = Szene
    @State private var sceneName: String = ""

    var body: some View {
        NavigationView {
            Form {
                TextField("Name (z.B. \"Aufwachen\")", text: $name)

                Picker("Auslöser", selection: $triggerType) {
                    Text("Feste Uhrzeit").tag(0)
                    Text("Sonnenuntergang").tag(1)
                    Text("Sonnenaufgang").tag(2)
                }

                if triggerType == 0 {
                    DatePicker("Uhrzeit", selection: $time, displayedComponents: .hourAndMinute)
                } else {
                    VStack(alignment: .leading) {
                        Text("Versatz: \(Int(offsetMinutes)) Minuten")
                        Slider(value: $offsetMinutes, in: -120...120, step: 5)
                    }
                }

                Picker("Aktion", selection: $actionType) {
                    Text("Licht an").tag(0)
                    Text("Licht aus").tag(1)
                    Text("Szene starten").tag(2)
                }

                if actionType == 2 {
                    Picker("Szene", selection: $sceneName) {
                        ForEach(sceneStore.scenes) { scene in
                            Text(scene.name).tag(scene.name)
                        }
                    }
                }

                if triggerType != 0 {
                    Section {
                        Text("Für wirklich exakte Sonnenzeiten die Kurzbefehle-Automatisierung nutzen (siehe vorherige Seite) - diese App kennt deinen Standort nicht und kann Sonnenauf-/-untergang daher nur als Vorlage speichern, nicht selbst exakt auslösen.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Neuer Zeitplan")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") { save() }
                        .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if sceneName.isEmpty { sceneName = sceneStore.scenes.first?.name ?? "" }
            }
        }
    }

    private func save() {
        let trigger: ScheduleTrigger
        switch triggerType {
        case 1: trigger = .sunset(offsetMinutes: Int(offsetMinutes))
        case 2: trigger = .sunrise(offsetMinutes: Int(offsetMinutes))
        default:
            let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
            trigger = .fixedTime(hour: comps.hour ?? 0, minute: comps.minute ?? 0)
        }
        let action: ScheduleAction
        switch actionType {
        case 1: action = .powerOff
        case 2: action = .scene(name: sceneName)
        default: action = .powerOn
        }
        scheduleStore.schedules.append(LightSchedule(name: name, trigger: trigger, action: action))
        dismiss()
    }
}

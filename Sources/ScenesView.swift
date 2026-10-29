import SwiftUI

struct ScenesView: View {
    @EnvironmentObject var bt: BluetoothManager
    @ObservedObject var sceneStore: SceneStore
    @ObservedObject var effectEngine: EffectEngine

    @State private var selectedDeviceIDs: Set<UUID> = []
    @State private var showNewSceneSheet = false

    var body: some View {
        NavigationView {
            Form {
                Section("Gilt für") {
                    if bt.connectedDevices.isEmpty {
                        Text("Erst ein Gerät verbinden.").foregroundStyle(.secondary)
                    } else {
                        ForEach(bt.connectedDevices) { device in
                            Toggle(device.name, isOn: Binding(
                                get: { selectedDeviceIDs.contains(device.id) },
                                set: { isOn in
                                    if isOn { selectedDeviceIDs.insert(device.id) } else { selectedDeviceIDs.remove(device.id) }
                                }
                            ))
                        }
                        Button("Alle auswählen") {
                            selectedDeviceIDs = Set(bt.connectedDevices.map { $0.id })
                        }
                        .font(.caption)
                    }
                }

                if effectEngine.isRunning {
                    Section {
                        HStack {
                            Text("Läuft: \(effectEngine.activeSceneName ?? "")").bold()
                            Spacer()
                            Button("Stoppen", role: .destructive) { effectEngine.stop() }
                        }
                    }
                }

                Section("Effekte") {
                    ForEach(sceneStore.scenes) { scene in
                        Button {
                            effectEngine.start(scene: scene, bt: bt, deviceIDs: Array(selectedDeviceIDs))
                        } label: {
                            HStack {
                                Image(systemName: scene.effect.systemImageName)
                                    .frame(width: 24)
                                VStack(alignment: .leading) {
                                    Text(scene.name)
                                    Text(scene.effect.rawValue).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(selectedDeviceIDs.isEmpty)
                    }
                    .onDelete { indexSet in
                        sceneStore.scenes.remove(atOffsets: indexSet)
                    }
                }

                Section {
                    Button("Eigenen Effekt hinzufügen") { showNewSceneSheet = true }
                } footer: {
                    Text("Auch per Siri: \"Hey Siri, starte [App-Name] Szene Weihnachten\".")
                }
            }
            .navigationTitle("Szenen")
            .sheet(isPresented: $showNewSceneSheet) {
                NewSceneSheet(sceneStore: sceneStore)
            }
        }
    }
}

struct NewSceneSheet: View {
    @ObservedObject var sceneStore: SceneStore
    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var effect: LightEffect = .rainbow
    @State private var speed: Double = 50

    var body: some View {
        NavigationView {
            Form {
                TextField("Name (z.B. \"Zocken\")", text: $name)
                Picker("Effekt", selection: $effect) {
                    ForEach(LightEffect.allCases) { effect in
                        Text(effect.rawValue).tag(effect)
                    }
                }
                VStack(alignment: .leading) {
                    Text("Geschwindigkeit")
                    Slider(value: $speed, in: 0...100)
                }
            }
            .navigationTitle("Neuer Effekt")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        sceneStore.scenes.append(LightScene(name: name.isEmpty ? effect.rawValue : name, effect: effect, speedPercent: speed))
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

import SwiftUI
import UniformTypeIdentifiers

struct MusicSyncView: View {
    @EnvironmentObject var bt: BluetoothManager
    @StateObject private var engine = MusicSyncEngine()
    @State private var showImporter = false
    @State private var selectedDeviceIDs: Set<UUID> = []

    var body: some View {
        NavigationView {
            Form {
                Section("Geräte") {
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
                    }
                }

                Section("Titel") {
                    if let name = engine.trackName {
                        Text(name)
                    } else {
                        Text("Keine Datei ausgewählt.").foregroundStyle(.secondary)
                    }
                    Button("MP3 aus Dateien wählen") { showImporter = true }
                }

                if engine.trackName != nil {
                    Section {
                        HStack(spacing: 16) {
                            Button {
                                if engine.isPlaying {
                                    engine.pause()
                                } else {
                                    engine.play(bt: bt, deviceIDs: Array(selectedDeviceIDs))
                                }
                            } label: {
                                Image(systemName: engine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 36))
                            }
                            .disabled(selectedDeviceIDs.isEmpty)

                            ProgressView(value: engine.progress)
                        }
                        if selectedDeviceIDs.isEmpty {
                            Text("Wähle oben mindestens ein Gerät aus.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Text("Die Lampen pulsieren während der Wiedergabe im Takt der Lautstärke der ausgewählten MP3-Datei, die Farbe wandert dabei langsam durch den Regenbogen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Musik-Modus")
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.mp3, .audio], onCompletion: { result in
                if case .success(let url) = result {
                    engine.load(url: url)
                }
            })
            .onDisappear { engine.stop() }
        }
    }
}

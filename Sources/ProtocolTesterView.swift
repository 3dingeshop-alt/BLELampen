import SwiftUI
import UniformTypeIdentifiers

/// Werkzeug, um bei einem noch unbekannten oder nur teilweise verstandenen Controller
/// (z.B. DMRRBA-007) gezielt Testbefehle zu senden, das Ergebnis selbst zu bewerten
/// ("hat geklappt" / "nichts passiert") und am Ende ein Protokoll zu exportieren.
struct ProtocolTesterView: View {
    @EnvironmentObject var bt: BluetoothManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedDeviceID: UUID?
    @State private var customHex: String = ""
    @State private var results: [TestResult] = []
    @State private var exportURL: IdentifiableURL?

    /// nil = keine Selbstprüfung aktiv. Sonst: Index des gerade laufenden Testbefehls
    /// aus TestCommandLibrary.candidates.
    @State private var autoTestIndex: Int?

    private var isAutoTesting: Bool { autoTestIndex != nil }

    struct TestResult: Identifiable {
        let id = UUID()
        let date = Date()
        let name: String
        let hex: String
        var verdict: String? // "funktioniert" / "nichts passiert" / nil = noch offen
    }

    private var selectedDevice: LEDDevice? {
        bt.connectedDevices.first(where: { $0.id == selectedDeviceID })
            ?? bt.connectedDevices.first
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Gerät") {
                    if bt.connectedDevices.isEmpty {
                        Text("Erst ein Gerät verbinden.").foregroundStyle(.secondary)
                    } else {
                        Picker("Gerät", selection: Binding(
                            get: { selectedDeviceID ?? bt.connectedDevices.first?.id },
                            set: { selectedDeviceID = $0 }
                        )) {
                            ForEach(bt.connectedDevices) { device in
                                Text(device.name).tag(device.id as UUID?)
                            }
                        }
                    }
                }

                Section("Automatische Selbstprüfung") {
                    if isAutoTesting, let index = autoTestIndex, index < TestCommandLibrary.candidates.count {
                        let candidate = TestCommandLibrary.candidates[index]
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Test \(index + 1) von \(TestCommandLibrary.candidates.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(candidate.name).font(.headline)
                            Text(candidate.hex).font(.caption2).foregroundStyle(.secondary)
                            Text("Hat sich an der Lampe gerade etwas verändert?")
                                .font(.subheadline)
                            HStack {
                                Button("✅ Ja") { autoTestAnswer(worked: true) }
                                    .buttonStyle(.borderedProminent)
                                Button("❌ Nein") { autoTestAnswer(worked: false) }
                                    .buttonStyle(.bordered)
                            }
                            Button("Selbstprüfung abbrechen", role: .destructive) {
                                autoTestIndex = nil
                            }
                            .font(.caption)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button("Selbstprüfung starten") { startAutoTest() }
                            .disabled(selectedDevice == nil)
                        Text("Geht automatisch alle vordefinierten Testbefehle unten der Reihe nach durch. Du bestätigst nach jedem einzelnen nur noch, ob sich etwas verändert hat.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Eigener Hex-Befehl") {
                    TextField("z.B. 56 ff 00 00 00 f0 aa", text: $customHex)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    Button("Senden") {
                        sendAndRecord(name: "Manuell", hex: customHex)
                    }
                    .disabled(Data(hexString: customHex) == nil || selectedDevice == nil || isAutoTesting)
                }

                Section("Vordefinierte Testbefehle") {
                    ForEach(TestCommandLibrary.candidates) { candidate in
                        Button {
                            sendAndRecord(name: candidate.name, hex: candidate.hex)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(candidate.name)
                                Text(candidate.hex).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .disabled(selectedDevice == nil || isAutoTesting)
                    }
                }

                if !results.isEmpty {
                    Section("Ergebnisse (neueste zuerst)") {
                        ForEach(results.reversed()) { result in
                            resultRow(result)
                        }
                    }
                }
            }
            .navigationTitle("Protokoll-Tester")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Exportieren") { export() }
                        .disabled(results.isEmpty)
                }
            }
            .sheet(item: $exportURL) { item in
                ShareSheet(activityItems: [item.url])
            }
        }
    }

    @ViewBuilder
    private func resultRow(_ result: TestResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.name).font(.subheadline.bold())
            Text(result.hex).font(.caption2).foregroundStyle(.secondary)
            HStack {
                Button("✅ Hat funktioniert") { setVerdict(result.id, "funktioniert") }
                    .buttonStyle(.bordered)
                Button("❌ Nichts passiert") { setVerdict(result.id, "nichts passiert") }
                    .buttonStyle(.bordered)
            }
            .font(.caption)
            if let verdict = result.verdict {
                Text("Bewertet als: \(verdict)")
                    .font(.caption2)
                    .foregroundStyle(verdict == "funktioniert" ? .green : .red)
            }
        }
        .padding(.vertical, 4)
    }

    private func startAutoTest() {
        guard selectedDevice != nil, !TestCommandLibrary.candidates.isEmpty else { return }
        autoTestIndex = 0
        sendAutoTestCurrent()
    }

    private func sendAutoTestCurrent() {
        guard let index = autoTestIndex, index < TestCommandLibrary.candidates.count else { return }
        let candidate = TestCommandLibrary.candidates[index]
        sendAndRecord(name: candidate.name, hex: candidate.hex)
    }

    private func autoTestAnswer(worked: Bool) {
        guard let index = autoTestIndex else { return }
        if let last = results.last {
            setVerdict(last.id, worked ? "funktioniert" : "nichts passiert")
        }
        let next = index + 1
        if next < TestCommandLibrary.candidates.count {
            autoTestIndex = next
            sendAutoTestCurrent()
        } else {
            autoTestIndex = nil
        }
    }

    private func sendAndRecord(name: String, hex: String) {
        guard let device = selectedDevice, let data = Data(hexString: hex) else { return }
        bt.send(data, to: device)
        results.append(TestResult(name: name, hex: data.hexString))
    }

    private func setVerdict(_ id: UUID, _ verdict: String) {
        if let index = results.firstIndex(where: { $0.id == id }) {
            results[index].verdict = verdict
        }
    }

    private func export() {
        var text = "Protokoll-Test – \(Date().formatted())\n"
        text += "Gerät: \(selectedDevice?.name ?? "unbekannt")\n\n"
        for result in results {
            text += "[\(result.date.formatted(date: .omitted, time: .standard))] \(result.name)\n"
            text += "  Hex: \(result.hex)\n"
            text += "  Bewertung: \(result.verdict ?? "nicht bewertet")\n\n"
        }
        if let device = selectedDevice {
            text += "\n--- Vollständiges Geräte-Log ---\n"
            for entry in device.log {
                text += "[\(entry.date.formatted(date: .omitted, time: .standard))] \(entry.text)\n"
            }
        }

        let fileName = "protokoll-test-\(Int(Date().timeIntervalSince1970)).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? text.write(to: url, atomically: true, encoding: .utf8)
        exportURL = IdentifiableURL(url: url)
    }
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

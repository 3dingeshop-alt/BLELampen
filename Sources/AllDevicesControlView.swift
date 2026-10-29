import SwiftUI

/// Steuert alle gerade verbundenen Geräte gemeinsam - z.B. alle LEDs im Zimmer
/// gleichzeitig auf dieselbe Farbe und Helligkeit stellen.
struct AllDevicesControlView: View {
    @EnvironmentObject var bt: BluetoothManager
    @State private var color: Color = .white
    @State private var brightness: Double = 1.0
    @State private var isOn: Bool = true

    var body: some View {
        Form {
            Section("Gilt für \(bt.connectedDevices.count) verbundene Geräte") {
                ForEach(bt.connectedDevices) { device in
                    HStack {
                        Text(device.name)
                        Spacer()
                        Text(device.protocolType.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Ein / Aus") {
                Toggle("Alle eingeschaltet", isOn: $isOn)
                    .onChange(of: isOn) { newValue in
                        bt.sendToAllConnected { device in
                            newValue ? device.commands.powerOn() : device.commands.powerOff()
                        }
                    }
            }

            Section("Farbe") {
                ColorPicker("Farbe für alle", selection: $color, supportsOpacity: false)
                    .onChange(of: color) { newValue in
                        let rgb = newValue.rgbComponents()
                        bt.sendToAllConnected { device in
                            device.commands.colorPackets(r: rgb.r, g: rgb.g, b: rgb.b)
                        }
                    }
            }

            Section("Helligkeit") {
                Slider(value: $brightness, in: 0...1) { editing in
                    if !editing {
                        let percent = Int(brightness * 100)
                        bt.sendToAllConnected { device in
                            device.commands.setBrightness(percent: percent)
                        }
                    }
                }
                Text("\(Int(brightness * 100)) %")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("Geräte, deren Protokoll noch nicht entschlüsselt ist, reagieren hier nicht mit - die steuerst du einzeln über den Protokoll-Tester.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Alle Geräte")
    }
}

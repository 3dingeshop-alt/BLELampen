import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DeviceControlView: View {
    @EnvironmentObject var bt: BluetoothManager
    @ObservedObject var device: LEDDevice

    var body: some View {
        Form {
            Section("Protokoll") {
                Picker("Erkannt als", selection: $device.protocolType) {
                    ForEach(LEDProtocolType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
            }

            if device.protocolType.commandBuilder.setColor(r: 0, g: 0, b: 0) != nil {
                Section("Ein / Aus") {
                    Toggle("Eingeschaltet", isOn: $device.isPoweredOn)
                        .onChange(of: device.isPoweredOn) { newValue in
                            let data = newValue ? device.commands.powerOn() : device.commands.powerOff()
                            if let data { bt.send(data, to: device) }
                        }
                }

                Section("Farbe") {
                    ColorPicker("Farbe wählen", selection: $device.color, supportsOpacity: false)
                        .onChange(of: device.color) { newValue in
                            sendColor(newValue)
                        }
                }

                Section("Helligkeit") {
                    Slider(value: $device.brightness, in: 0...1) { editing in
                        if !editing {
                            sendBrightness(device.brightness)
                        }
                    }
                    Text("\(Int(device.brightness * 100)) %")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    Text("Für dieses Protokoll sind Farbe und Helligkeit noch nicht entschlüsselt. Nutze den Protokoll-Tester (Schraubenschlüssel-Symbol auf der Startseite), um Testbefehle zu senden und herauszufinden, welche funktionieren.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Verbindung") {
                Button("Trennen", role: .destructive) {
                    bt.disconnect(device)
                }
            }

            Section("Protokoll-Log") {
                if device.log.isEmpty {
                    Text("Noch keine Einträge.").foregroundStyle(.secondary)
                } else {
                    ForEach(device.log.reversed()) { entry in
                        Text(entry.text)
                            .font(.system(.caption2, design: .monospaced))
                    }
                }
            }
        }
        .navigationTitle(device.name)
    }

    private func sendColor(_ color: Color) {
        let components = color.rgbComponents()
        if let data = device.commands.setColor(r: components.r, g: components.g, b: components.b) {
            bt.send(data, to: device)
        }
    }

    private func sendBrightness(_ value: Double) {
        if let data = device.commands.setBrightness(percent: Int(value * 100)) {
            bt.send(data, to: device)
        }
    }
}

extension Color {
    /// Wandelt eine SwiftUI Color in 0-255 RGB-Bytes um.
    func rgbComponents() -> (r: UInt8, g: UInt8, b: UInt8) {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (UInt8(max(0, min(255, red * 255))),
                UInt8(max(0, min(255, green * 255))),
                UInt8(max(0, min(255, blue * 255))))
        #else
        return (255, 255, 255)
        #endif
    }
}

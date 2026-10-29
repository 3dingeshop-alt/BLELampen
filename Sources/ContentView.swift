import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bt: BluetoothManager
    @State private var showTester = false

    var body: some View {
        NavigationView {
            List {
                if !bt.connectedDevices.isEmpty {
                    Section("Verbunden") {
                        ForEach(bt.connectedDevices) { device in
                            NavigationLink {
                                DeviceControlView(device: device)
                            } label: {
                                deviceRow(device, connected: true)
                            }
                        }

                        if bt.connectedDevices.count > 1 {
                            NavigationLink {
                                AllDevicesControlView()
                            } label: {
                                Label("Alle gleichzeitig steuern", systemImage: "square.stack.3d.up.fill")
                            }
                        }
                    }
                }

                Section("Gefunden") {
                    ForEach(bt.visibleDiscoveredDevices) { device in
                        Button {
                            bt.connect(device)
                        } label: {
                            deviceRow(device, connected: false)
                        }
                    }
                    if bt.visibleDiscoveredDevices.isEmpty {
                        Text(bt.isScanning ? "Suche läuft…" : "Keine Geräte gefunden.")
                            .foregroundStyle(.secondary)
                    }
                    if !bt.showAllDevices && bt.hiddenDeviceCount > 0 {
                        Button {
                            bt.showAllDevices = true
                        } label: {
                            Text("+ \(bt.hiddenDeviceCount) weitere Geräte in der Nähe ausblenden (Fernseher, Kopfhörer usw.) - zum Anzeigen tippen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("LED-Lampen")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showTester = true
                    } label: {
                        Image(systemName: "wrench.and.screwdriver")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        bt.showAllDevices.toggle()
                    } label: {
                        Image(systemName: bt.showAllDevices ? "eye" : "eye.slash")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        bt.isScanning ? bt.stopScanning() : bt.startScanning()
                    } label: {
                        Image(systemName: bt.isScanning ? "stop.circle" : "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showTester) {
                ProtocolTesterView()
                    .environmentObject(bt)
            }
            .overlay {
                if !bt.isBluetoothReady {
                    ContentUnavailableFallback()
                }
            }
        }
    }

    @ViewBuilder
    private func deviceRow(_ device: LEDDevice, connected: Bool) -> some View {
        HStack {
            Image(systemName: connected ? "lightbulb.fill" : "antenna.radiowaves.left.and.right")
                .foregroundStyle(connected ? .yellow : .blue)
            VStack(alignment: .leading) {
                Text(device.name).font(.headline)
                Text(device.protocolType.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !connected {
                Text("\(device.rssi) dBm").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

/// Einfacher Ersatz für ContentUnavailableView, falls Bluetooth noch nicht bereit ist
/// (funktioniert auch unter iOS 16, ContentUnavailableView gibt es erst ab iOS 17).
struct ContentUnavailableFallback: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 40))
            Text("Bluetooth nicht verfügbar")
                .font(.headline)
            Text("Bitte Bluetooth einschalten und der App in den Einstellungen erlauben.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
        }
        .padding()
        .background(.thinMaterial)
    }
}

#Preview {
    ContentView().environmentObject(BluetoothManager())
}

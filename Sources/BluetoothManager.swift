import Foundation
import CoreBluetooth
import Combine

/// Verwaltet Scan, Verbindungen und Datenübertragung für beliebig viele LED-Controller
/// gleichzeitig. Dient als Delegate für den zentralen Manager UND für jedes verbundene
/// Peripheral (die Zuordnung erfolgt über peripheral.identifier).
final class BluetoothManager: NSObject, ObservableObject {

    /// Eine einzige geteilte Instanz für die ganze App - wichtig, damit Siri-Befehle/
    /// Kurzbefehle (App Intents) dieselben verbundenen Geräte steuern, die auch in der
    /// normalen App-Oberfläche zu sehen sind, statt eine eigene, leere Instanz zu benutzen.
    static let shared = BluetoothManager()

    @Published var isBluetoothReady = false
    @Published var isScanning = false

    /// Alle beim Scan gefundenen Geräte (noch nicht zwingend verbunden).
    @Published var discoveredDevices: [LEDDevice] = []

    /// Standardmäßig AUS: zeigt in der Geräteliste nur erkannte LED-Controller
    /// (ELK-BLEDOM/BLEDDM, DMRRBA-007) statt jedes Bluetooth-Gerät in der Nähe
    /// (Fernseher, Kopfhörer usw.). Über den Button in der Toolbar umschaltbar.
    @Published var showAllDevices = false

    /// Was in der Liste tatsächlich angezeigt werden soll: ungefiltert, wenn showAllDevices
    /// an ist oder das Gerät schon verbunden ist, sonst nur erkannte Protokolle.
    var visibleDiscoveredDevices: [LEDDevice] {
        discoveredDevices.filter { device in
            !device.isConnected && (showAllDevices || device.protocolType != .unknown)
        }
    }

    var hiddenDeviceCount: Int {
        discoveredDevices.filter { !$0.isConnected && $0.protocolType == .unknown }.count
    }

    /// Nur die aktuell verbundenen Geräte - das sind die, die in der Steuerungs-Ansicht auftauchen.
    @Published var connectedDevices: [LEDDevice] = []

    private var central: CBCentralManager!
    private var peripheralsByID: [UUID: CBPeripheral] = [:]

    // Service-UUIDs, die wir beim automatischen Erkennen der Schreib-Characteristic
    // NICHT als Steuerkanal verwenden wollen, weil es Standard-Systemdienste sind.
    private let ignoredServiceUUIDs: Set<CBUUID> = [
        CBUUID(string: "1800"), // Generic Access
        CBUUID(string: "1801"), // Generic Attribute
        CBUUID(string: "180A"), // Device Information
        CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E") // Nordic UART Service
    ]

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Scannen

    func startScanning() {
        guard central.state == .poweredOn else { return }
        discoveredDevices.removeAll()
        isScanning = true
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func stopScanning() {
        central.stopScan()
        isScanning = false
    }

    // MARK: - Verbinden

    func connect(_ device: LEDDevice) {
        peripheralsByID[device.id] = device.peripheral
        device.peripheral.delegate = self
        central.connect(device.peripheral, options: nil)
    }

    func disconnect(_ device: LEDDevice) {
        central.cancelPeripheralConnection(device.peripheral)
    }

    // MARK: - Senden

    func send(_ data: Data, to device: LEDDevice) {
        guard let characteristic = device.writeCharacteristic else {
            device.addLog("Senden fehlgeschlagen: keine Schreib-Characteristic gefunden.")
            return
        }
        device.peripheral.writeValue(data, for: characteristic, type: device.writeType)
        device.addLog("TX  \(data.hexString)")
    }

    /// Sendet mehrere Pakete nacheinander mit kleiner Pause dazwischen (manche Controller,
    /// z.B. DMRRBA-007, brauchen das zwischen zwei zusammengehörigen Befehlen).
    func send(_ packets: [Data], to device: LEDDevice) {
        for (index, packet) in packets.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.03) { [weak self] in
                self?.send(packet, to: device)
            }
        }
    }

    func sendToAllConnected(_ makeData: (LEDDevice) -> Data?) {
        for device in connectedDevices {
            if let data = makeData(device) {
                send(data, to: device)
            }
        }
    }

    func sendToAllConnected(_ makePackets: (LEDDevice) -> [Data]) {
        for device in connectedDevices {
            send(makePackets(device), to: device)
        }
    }

    // MARK: - Hilfsfunktionen

    private func findOrCreateDevice(for peripheral: CBPeripheral, rssi: Int) -> LEDDevice {
        if let existing = discoveredDevices.first(where: { $0.id == peripheral.identifier }) {
            return existing
        }
        let name = peripheral.name ?? "Unbekanntes Gerät"
        let device = LEDDevice(peripheral: peripheral, name: name, rssi: rssi)
        return device
    }

    private func device(for peripheral: CBPeripheral) -> LEDDevice? {
        connectedDevices.first(where: { $0.id == peripheral.identifier })
            ?? discoveredDevices.first(where: { $0.id == peripheral.identifier })
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBluetoothReady = (central.state == .poweredOn)
        if central.state == .poweredOn {
            startScanning()
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                         advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? peripheral.name
            ?? "Unbekanntes Gerät"

        DispatchQueue.main.async {
            if let index = self.discoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
                self.discoveredDevices[index].rssi = RSSI.intValue
                if self.discoveredDevices[index].name == "Unbekanntes Gerät" {
                    self.discoveredDevices[index].name = name
                    self.discoveredDevices[index].protocolType = LEDProtocolType.detect(fromName: name)
                }
            } else {
                let device = self.findOrCreateDevice(for: peripheral, rssi: RSSI.intValue)
                device.name = name
                device.protocolType = LEDProtocolType.detect(fromName: name)
                self.discoveredDevices.append(device)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let device = discoveredDevices.first(where: { $0.id == peripheral.identifier }) else { return }
        DispatchQueue.main.async {
            device.isConnected = true
            if !self.connectedDevices.contains(where: { $0.id == device.id }) {
                self.connectedDevices.append(device)
            }
        }
        device.addLog("Verbunden mit \(device.name).")
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        device(for: peripheral)?.addLog("Verbindung fehlgeschlagen: \(error?.localizedDescription ?? "unbekannter Fehler")")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let device = connectedDevices.first(where: { $0.id == peripheral.identifier }) {
            device.addLog("Verbindung getrennt.")
            DispatchQueue.main.async {
                device.isConnected = false
                self.connectedDevices.removeAll { $0.id == device.id }
            }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let device = device(for: peripheral) else { return }
        if let error = error {
            device.addLog("Service-Suche fehlgeschlagen: \(error.localizedDescription)")
            return
        }
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let device = device(for: peripheral) else { return }
        if let error = error {
            device.addLog("Characteristic-Suche fehlgeschlagen: \(error.localizedDescription)")
            return
        }

        // Manche Protokolle (z.B. DMRRBA-007) schreiben eine ganz bestimmte Characteristic
        // vor - auch wenn die in der generischen Ignorierliste steht (Nordic UART). Ist das
        // der Fall, zählt NUR diese, die generische Erkennung darunter wird übersprungen.
        let forcedWrite = device.protocolType.forcedWriteUUID.map { CBUUID(string: $0) }
        let forcedNotify = device.protocolType.forcedNotifyUUID.map { CBUUID(string: $0) }

        for characteristic in service.characteristics ?? [] {
            let canWrite = characteristic.properties.contains(.writeWithoutResponse)
                || characteristic.properties.contains(.write)

            if let forcedWrite {
                if canWrite && characteristic.uuid == forcedWrite && device.writeCharacteristic == nil {
                    device.writeCharacteristic = characteristic
                    device.writeType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
                    device.addLog("Schreib-Characteristic (fest zugeordnet): \(characteristic.uuid) in Service \(service.uuid)")
                    for handshakeData in device.commands.handshake() {
                        send(handshakeData, to: device)
                    }
                }
            } else {
                // Schreib-Characteristic auswählen: bevorzugt eine aus einem herstellerspezifischen
                // Service (nicht Device Information / Generic Access / Nordic UART), die Write ohne
                // Antwort unterstützt.
                let isIgnoredService = ignoredServiceUUIDs.contains(service.uuid)
                if canWrite && device.writeCharacteristic == nil && !isIgnoredService {
                    device.writeCharacteristic = characteristic
                    device.writeType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
                    device.addLog("Schreib-Characteristic gefunden: \(characteristic.uuid) in Service \(service.uuid)")
                    for handshakeData in device.commands.handshake() {
                        send(handshakeData, to: device)
                    }
                }
            }

            if characteristic.properties.contains(.notify) {
                if forcedNotify == nil || characteristic.uuid == forcedNotify {
                    peripheral.setNotifyValue(true, for: characteristic)
                    device.notifyCharacteristic = characteristic
                }
            }
        }

        // Falls bis hierhin noch keine Schreib-Characteristic feststeht und das Protokoll
        // KEINE feste Characteristic vorschreibt (z.B. weil alle gefundenen Services als
        // "ignoriert" markiert waren), nimm die erste beschreibbare, die überhaupt existiert -
        // besser als gar nichts.
        if device.writeCharacteristic == nil && forcedWrite == nil {
            for characteristic in service.characteristics ?? [] {
                if characteristic.properties.contains(.writeWithoutResponse) || characteristic.properties.contains(.write) {
                    device.writeCharacteristic = characteristic
                    device.writeType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
                    device.addLog("Schreib-Characteristic (Fallback): \(characteristic.uuid)")
                    break
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let device = device(for: peripheral) else { return }
        if let error = error {
            device.addLog("Fehler beim Empfang: \(error.localizedDescription)")
            return
        }
        if let value = characteristic.value, !value.isEmpty {
            device.addLog("RX  \(value.hexString)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            device(for: peripheral)?.addLog("Schreibfehler: \(error.localizedDescription)")
        }
    }
}

import Foundation
import CoreBluetooth
import SwiftUI

/// Repräsentiert ein gescanntes oder verbundenes LED-Gerät.
final class LEDDevice: ObservableObject, Identifiable {
    let id: UUID
    let peripheral: CBPeripheral

    @Published var name: String
    @Published var rssi: Int
    @Published var isConnected: Bool = false
    @Published var protocolType: LEDProtocolType
    @Published var color: Color = .white
    @Published var brightness: Double = 1.0
    @Published var isPoweredOn: Bool = true
    @Published var log: [LogEntry] = []

    var writeCharacteristic: CBCharacteristic?
    var writeType: CBCharacteristicWriteType = .withoutResponse
    var notifyCharacteristic: CBCharacteristic?

    struct LogEntry: Identifiable {
        let id = UUID()
        let date = Date()
        let text: String
    }

    init(peripheral: CBPeripheral, name: String, rssi: Int) {
        self.id = peripheral.identifier
        self.peripheral = peripheral
        self.name = name
        self.rssi = rssi
        self.protocolType = LEDProtocolType.detect(fromName: name)
    }

    func addLog(_ text: String) {
        DispatchQueue.main.async {
            self.log.append(LogEntry(text: text))
            if self.log.count > 300 {
                self.log.removeFirst(self.log.count - 300)
            }
        }
    }

    var commands: LEDCommandBuilder {
        protocolType.commandBuilder
    }
}

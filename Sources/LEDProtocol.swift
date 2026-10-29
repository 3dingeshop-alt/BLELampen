import Foundation

// MARK: - Protokoll-Typ

enum LEDProtocolType: String, CaseIterable, Identifiable {
    case elkBledom = "ELK-BLEDOM / BLEDDM"
    case dmrrba007 = "DMRRBA-007"
    case unknown = "Unbekannt / manuell"

    var id: String { rawValue }

    /// Versucht, den Protokoll-Typ anhand des beworbenen Gerätenamens zu erkennen.
    static func detect(fromName name: String) -> LEDProtocolType {
        let upper = name.uppercased()
        if upper.contains("ELK") || upper.contains("BLEDOM") || upper.contains("BLEDDM") {
            return .elkBledom
        }
        if upper.contains("DMRRBA") {
            return .dmrrba007
        }
        return .unknown
    }

    var commandBuilder: LEDCommandBuilder {
        switch self {
        case .elkBledom:
            return ElkBledomCommands()
        case .dmrrba007:
            return DMRRBA007Commands()
        case .unknown:
            return UnknownCommands()
        }
    }

    /// Manche Controller (hier: DMRRBA-007) senden ihre echten Befehle über einen Service,
    /// den die generische Auto-Erkennung sonst als "Systemdienst" ignorieren würde (der
    /// Hersteller nutzt die Standard-Nordic-UART-Service-UUID für eigene Zwecke weiter).
    /// Ist hier ein Wert gesetzt, wird GENAU diese Service-/Schreib-Characteristic benutzt,
    /// statt die generische Erkennung (und deren Ignorierliste) laufen zu lassen.
    var forcedServiceUUID: String? {
        switch self {
        case .dmrrba007: return "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
        default: return nil
        }
    }

    var forcedWriteUUID: String? {
        switch self {
        case .dmrrba007: return "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
        default: return nil
        }
    }

    var forcedNotifyUUID: String? {
        switch self {
        case .dmrrba007: return "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
        default: return nil
        }
    }
}

// MARK: - Gemeinsames Interface für alle Protokolle

protocol LEDCommandBuilder {
    /// Befehle, die direkt nach dem Verbindungsaufbau gesendet werden sollen (Handshake), falls nötig.
    func handshake() -> [Data]

    func powerOn() -> Data?
    func powerOff() -> Data?

    /// nil, wenn das Protokoll keine direkten RGB-Befehle unterstützt.
    func setColor(r: UInt8, g: UInt8, b: UInt8) -> Data?

    /// Helligkeit 0...100 Prozent. nil, wenn nicht unterstützt.
    func setBrightness(percent: Int) -> Data?

    /// Im Normalfall ist "Farbe setzen" ein einzelner Befehl (siehe Standard-Implementierung
    /// unten). Protokolle mit mehrteiligen Farbbefehlen (z.B. DMRRBA-007: erst Farbmodus
    /// aktivieren, dann die RGB-Werte) überschreiben das und liefern mehrere Pakete, die
    /// nacheinander gesendet werden. Muss hier als Protokoll-Anforderung stehen (nicht nur
    /// als Extension), sonst wird die Überschreibung beim Aufruf über den LEDCommandBuilder-
    /// Protokolltyp (wie device.commands) nicht benutzt.
    func colorPackets(r: UInt8, g: UInt8, b: UInt8) -> [Data]
}

extension LEDCommandBuilder {
    func colorPackets(r: UInt8, g: UInt8, b: UInt8) -> [Data] {
        setColor(r: r, g: g, b: b).map { [$0] } ?? []
    }
}

// MARK: - ELK-BLEDOM / ELK-BLEDDM (bestätigtes Protokoll aus dem Bluetooth-Log)
//
// Befehle enden immer mit 0xEF, beginnen mit 0x7E.
// Ein/Aus:      7E 04 04 <01|00> 00 <01|00> FF 00 EF
// Farbe setzen: 7E 07 05 03 <R> <G> <B> 10 EF
// Helligkeit:   7E 04 01 <0-64 hex, 0-100 dez> 01 FF FF 00 EF

struct ElkBledomCommands: LEDCommandBuilder {
    func handshake() -> [Data] { [] }

    func powerOn() -> Data? {
        Data([0x7e, 0x04, 0x04, 0x01, 0x00, 0x01, 0xff, 0x00, 0xef])
    }

    func powerOff() -> Data? {
        Data([0x7e, 0x04, 0x04, 0x00, 0x00, 0x00, 0xff, 0x00, 0xef])
    }

    func setColor(r: UInt8, g: UInt8, b: UInt8) -> Data? {
        Data([0x7e, 0x07, 0x05, 0x03, r, g, b, 0x10, 0xef])
    }

    func setBrightness(percent: Int) -> Data? {
        let clamped = UInt8(max(0, min(100, percent)))
        return Data([0x7e, 0x04, 0x01, clamped, 0x01, 0xff, 0xff, 0x00, 0xef])
    }
}

// MARK: - DMRRBA-007 (echtes Protokoll)
//
// Reverse engineered aus der Android-App "illumiHome" (com.lxillumi.illumihome), über den
// quelloffenen Homey-Treiber https://github.com/smarthomesven/homey-illumi-home, dessen
// Namensmuster "DMRRBA-00[1-9A]" unser Gerät exakt trifft. Kein Handshake nötig - die
// Befehle gehen direkt über die Nordic-UART-Service-Characteristic (siehe forcedWriteUUID
// oben in LEDProtocolType, die unsere generische Erkennung sonst ignorieren würde).
//
// Ein:         5A 01 02 01
// Aus:         5A 01 02 00
// Farbmodus:   5A 02 01 02        (immer VOR dem Farbbefehl senden)
// Farbe:       5A 07 01 <R> <G> <B>
// Helligkeit:  5A 03 01 <uint16, little-endian, 1...4095>

struct DMRRBA007Commands: LEDCommandBuilder {
    func handshake() -> [Data] { [] }

    func powerOn() -> Data? {
        Data([0x5a, 0x01, 0x02, 0x01])
    }

    func powerOff() -> Data? {
        Data([0x5a, 0x01, 0x02, 0x00])
    }

    func setColor(r: UInt8, g: UInt8, b: UInt8) -> Data? {
        colorPackets(r: r, g: g, b: b).last
    }

    func colorPackets(r: UInt8, g: UInt8, b: UInt8) -> [Data] {
        [
            Data([0x5a, 0x02, 0x01, 0x02]),
            Data([0x5a, 0x07, 0x01, r, g, b])
        ]
    }

    func setBrightness(percent: Int) -> Data? {
        let clampedPercent = max(0, min(100, percent))
        let value = max(1, Int((Double(clampedPercent) / 100.0 * 4095.0).rounded()))
        let lowByte = UInt8(value & 0xff)
        let highByte = UInt8((value >> 8) & 0xff)
        return Data([0x5a, 0x03, 0x01, lowByte, highByte])
    }
}

// MARK: - Unbekanntes Gerät (nur manuelles Senden im Tester)

struct UnknownCommands: LEDCommandBuilder {
    func handshake() -> [Data] { [] }
    func powerOn() -> Data? { nil }
    func powerOff() -> Data? { nil }
    func setColor(r: UInt8, g: UInt8, b: UInt8) -> Data? { nil }
    func setBrightness(percent: Int) -> Data? { nil }
}

// MARK: - Hex-Hilfsfunktionen

extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    init?(hexString: String) {
        let cleaned = hexString
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "0x", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count % 2 == 0, !cleaned.isEmpty else { return nil }
        var data = Data()
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        self = data
    }
}

// MARK: - Vordefinierte Testbefehle für den Protokoll-Tester
// (für noch unbekannte Controller, z.B. zukünftig neue Geräte wie "Lotus Lantern")

struct TestCommand: Identifiable {
    let id = UUID()
    let name: String
    let hex: String
}

enum TestCommandLibrary {
    static let candidates: [TestCommand] = [
        TestCommand(name: "DMRRBA-007 Ein (bestätigt)", hex: "5a 01 02 01"),
        TestCommand(name: "DMRRBA-007 Aus (bestätigt)", hex: "5a 01 02 00"),
        TestCommand(name: "DMRRBA-007 Farbmodus (bestätigt)", hex: "5a 02 01 02"),
        TestCommand(name: "Generisch Rot (0x56-Format)", hex: "56 ff 00 00 00 f0 aa"),
        TestCommand(name: "Generisch Grün (0x56-Format)", hex: "56 00 ff 00 00 f0 aa"),
        TestCommand(name: "Generisch Blau (0x56-Format)", hex: "56 00 00 ff 00 f0 aa"),
        TestCommand(name: "ELK-Format Rot", hex: "7e 07 05 03 ff 00 00 10 ef"),
        TestCommand(name: "ELK-Format Grün", hex: "7e 07 05 03 00 ff 00 10 ef"),
        TestCommand(name: "ELK-Format Blau", hex: "7e 07 05 03 00 00 ff 10 ef"),
        TestCommand(name: "ELK-Format Ein", hex: "7e 04 04 01 00 01 ff 00 ef"),
        TestCommand(name: "ELK-Format Aus", hex: "7e 04 04 00 00 00 ff 00 ef")
    ]
}

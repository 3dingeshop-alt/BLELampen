import Foundation

// MARK: - Protokoll-Typ

enum LEDProtocolType: String, CaseIterable, Identifiable {
    case elkBledom = "ELK-BLEDOM / BLEDDM"
    case dmrrba007 = "DMRRBA-007 (experimentell)"
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
}

// MARK: - Gemeinsames Interface für alle Protokolle

protocol LEDCommandBuilder {
    /// Befehle, die direkt nach dem Verbindungsaufbau gesendet werden sollen (Handshake), falls nötig.
    func handshake() -> [Data]

    func powerOn() -> Data?
    func powerOff() -> Data?

    /// nil, wenn das Protokoll keine direkten RGB-Befehle unterstützt (siehe DMRRBA-007).
    func setColor(r: UInt8, g: UInt8, b: UInt8) -> Data?

    /// Helligkeit 0...100 Prozent. nil, wenn nicht unterstützt.
    func setBrightness(percent: Int) -> Data?
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

// MARK: - DMRRBA-007 (noch nicht vollständig entschlüsselt)
//
// Aus dem Log bestätigt ist nur der Verbindungs-Handshake. Die Farb-/Helligkeitsbefehle
// scheinen fortlaufende Positionswerte eines Farbrads/Schiebereglers zu sein, keine
// direkten RGB-Werte - deshalb hier erstmal nicht nachgebaut. Benutze den
// Protokoll-Tester-Tab, um das mit gezielten Einzel-Taps weiter einzugrenzen.

struct DMRRBA007Commands: LEDCommandBuilder {
    func handshake() -> [Data] {
        [
            Data([0x5a, 0x01, 0x02, 0x01]),
            Data([0x5a, 0x02, 0x01, 0x01])
        ]
    }

    func powerOn() -> Data? { nil }
    func powerOff() -> Data? { nil }
    func setColor(r: UInt8, g: UInt8, b: UInt8) -> Data? { nil }
    func setBrightness(percent: Int) -> Data? { nil }
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
// (für noch unbekannte oder nur teilweise verstandene Controller wie den DMRRBA-007)

struct TestCommand: Identifiable {
    let id = UUID()
    let name: String
    let hex: String
}

enum TestCommandLibrary {
    static let candidates: [TestCommand] = [
        TestCommand(name: "DMRRBA Handshake 1", hex: "5a 01 02 01"),
        TestCommand(name: "DMRRBA Handshake 2", hex: "5a 02 01 01"),
        TestCommand(name: "DMRRBA Power An (Vermutung)", hex: "5a 02 01 04"),
        TestCommand(name: "DMRRBA Power Aus (Vermutung)", hex: "5a 02 01 05"),
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

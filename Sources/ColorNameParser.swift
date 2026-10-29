import Foundation

/// Übersetzt einen frei gesprochenen/getippten deutschen Farbnamen oder Hex-Code
/// (z.B. für "Hey Siri, mach das Licht blau") in RGB-Bytes.
enum ColorNameParser {
    private static let names: [String: (UInt8, UInt8, UInt8)] = [
        "rot": (255, 0, 0),
        "grün": (0, 255, 0),
        "gruen": (0, 255, 0),
        "blau": (0, 0, 255),
        "gelb": (255, 220, 0),
        "orange": (255, 140, 0),
        "lila": (160, 0, 220),
        "violett": (160, 0, 220),
        "pink": (255, 20, 147),
        "rosa": (255, 150, 200),
        "weiß": (255, 255, 255),
        "weiss": (255, 255, 255),
        "warmweiß": (255, 190, 120),
        "warmweiss": (255, 190, 120),
        "türkis": (0, 220, 200),
        "tuerkis": (0, 220, 200),
        "cyan": (0, 255, 255),
        "magenta": (255, 0, 255),
        "braun": (139, 69, 19),
        "gold": (255, 200, 40),
        "hellblau": (120, 190, 255),
        "dunkelblau": (0, 0, 140),
        "hellgrün": (140, 255, 140),
        "hellgruen": (140, 255, 140),
        "himmelblau": (135, 206, 235),
        "mint": (120, 255, 200)
    ]

    static func parse(_ raw: String) -> (UInt8, UInt8, UInt8)? {
        let cleaned = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = names[cleaned] { return direct }
        for (name, rgb) in names where cleaned.contains(name) {
            return rgb
        }
        let hexCandidate = cleaned.replacingOccurrences(of: "#", with: "")
        if hexCandidate.count == 6, let data = Data(hexString: hexCandidate), data.count == 3 {
            return (data[0], data[1], data[2])
        }
        return nil
    }
}

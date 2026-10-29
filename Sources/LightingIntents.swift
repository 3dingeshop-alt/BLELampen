import AppIntents

// MARK: - Siri / Kurzbefehle
//
// Diese App Intents laufen auf denselben geteilten Instanzen wie die App-Oberfläche
// (siehe LightingEnvironment), damit "Hey Siri, mach das Licht blau" wirklich die gerade
// verbundenen Lampen steuert. Wichtig: Das funktioniert zuverlässig nur, solange die App
// schon einmal verbunden war/läuft (im Vorder- oder kurz im Hintergrund) - Siri kann die
// App zwar aufwecken, aber ohne eine schon bestehende Bluetooth-Verbindung braucht ein
// echter Verbindungsaufbau selbst ein paar Sekunden.

struct TurnLightsOnIntent: AppIntent {
    static var title: LocalizedStringResource = "Licht einschalten"
    static var description = IntentDescription("Schaltet alle verbundenen LED-Streifen ein.")

    func perform() async throws -> some IntentResult {
        LightingEnvironment.bt.sendToAllConnected { $0.commands.powerOn() }
        return .result()
    }
}

struct TurnLightsOffIntent: AppIntent {
    static var title: LocalizedStringResource = "Licht ausschalten"
    static var description = IntentDescription("Schaltet alle verbundenen LED-Streifen aus.")

    func perform() async throws -> some IntentResult {
        LightingEnvironment.bt.sendToAllConnected { $0.commands.powerOff() }
        return .result()
    }
}

struct SetLightColorIntent: AppIntent {
    static var title: LocalizedStringResource = "Lichtfarbe einstellen"
    static var description = IntentDescription("Stellt die Farbe aller verbundenen LED-Streifen frei nach Namen ein, z.B. Rot, Blau, Türkis.")

    @Parameter(title: "Farbe")
    var colorName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Licht \(\.$colorName) färben")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let rgb = ColorNameParser.parse(colorName) else {
            return .result(dialog: "Die Farbe \(colorName) kenne ich nicht.")
        }
        LightingEnvironment.bt.sendToAllConnected { device in
            device.commands.colorPackets(r: rgb.0, g: rgb.1, b: rgb.2)
        }
        return .result(dialog: "Licht ist jetzt \(colorName).")
    }
}

struct SetLightBrightnessIntent: AppIntent {
    static var title: LocalizedStringResource = "Helligkeit einstellen"
    static var description = IntentDescription("Stellt die Helligkeit aller verbundenen LED-Streifen in Prozent ein.")

    @Parameter(title: "Prozent", default: 100)
    var percent: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Helligkeit auf \(\.$percent) Prozent stellen")
    }

    func perform() async throws -> some IntentResult {
        let clamped = max(0, min(100, percent))
        LightingEnvironment.bt.sendToAllConnected { $0.commands.setBrightness(percent: clamped) }
        return .result()
    }
}

struct RunLightSceneIntent: AppIntent {
    static var title: LocalizedStringResource = "Lichtszene starten"
    static var description = IntentDescription("Startet eine gespeicherte Lichtszene/einen Effekt, z.B. Regenbogen, Halloween oder Weihnachten.")

    @Parameter(title: "Szene")
    var sceneName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Szene \(\.$sceneName) starten")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let scene = LightingEnvironment.scenes.scenes.first(where: { $0.name.lowercased() == sceneName.lowercased() }) else {
            return .result(dialog: "Die Szene \(sceneName) kenne ich nicht.")
        }
        let ids = LightingEnvironment.bt.connectedDevices.map { $0.id }
        LightingEnvironment.effects.start(scene: scene, bt: LightingEnvironment.bt, deviceIDs: ids)
        return .result(dialog: "Szene \(sceneName) läuft.")
    }
}

struct StopLightSceneIntent: AppIntent {
    static var title: LocalizedStringResource = "Lichteffekt stoppen"
    static var description = IntentDescription("Beendet einen laufenden Lichteffekt.")

    func perform() async throws -> some IntentResult {
        LightingEnvironment.effects.stop()
        return .result()
    }
}

/// Macht die obigen Intents als feste Kurzbefehle/Siri-Phrasen bekannt (zusätzlich
/// funktioniert auch die freie Siri-Steuerung mit beliebigem Farbnamen/Prozentwert, weil
/// die Parameter oben als offene Felder definiert sind statt als feste Auswahl).
struct BLELampenShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TurnLightsOnIntent(),
            phrases: ["Schalte \(.applicationName) ein", "\(.applicationName) Licht an"],
            shortTitle: "Licht an",
            systemImageName: "lightbulb.fill"
        )
        AppShortcut(
            intent: TurnLightsOffIntent(),
            phrases: ["Schalte \(.applicationName) aus", "\(.applicationName) Licht aus"],
            shortTitle: "Licht aus",
            systemImageName: "lightbulb.slash"
        )
        AppShortcut(
            intent: SetLightColorIntent(),
            phrases: ["Mach das Licht in \(.applicationName) \(\.$colorName)", "\(.applicationName) Farbe \(\.$colorName)"],
            shortTitle: "Farbe ändern",
            systemImageName: "paintpalette.fill"
        )
        AppShortcut(
            intent: SetLightBrightnessIntent(),
            phrases: ["Stell die Helligkeit in \(.applicationName) auf \(\.$percent) Prozent"],
            shortTitle: "Helligkeit",
            systemImageName: "sun.max"
        )
        AppShortcut(
            intent: RunLightSceneIntent(),
            phrases: ["Starte \(.applicationName) Szene \(\.$sceneName)", "\(.applicationName) \(\.$sceneName) Modus"],
            shortTitle: "Szene starten",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: StopLightSceneIntent(),
            phrases: ["Stoppe den Lichteffekt in \(.applicationName)"],
            shortTitle: "Effekt stoppen",
            systemImageName: "stop.fill"
        )
    }
}

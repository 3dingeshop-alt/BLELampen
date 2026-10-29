# BLELampen

iOS-App (SwiftUI + CoreBluetooth) zur Steuerung von Bluetooth-LE-LED-Controllern
(bestätigt funktionierend: ELK-BLEDOM / ELK-BLEDDM; experimentell: DMRRBA-007
über den eingebauten Protokoll-Tester).

## IPA über GitHub Actions bauen

1. Im Reiter "Actions" dieses Repos den Workflow "Build unsigned IPA" öffnen.
2. "Run workflow" klicken (oder einfach auf `main` pushen, dann läuft er automatisch).
3. Nach ein paar Minuten ist bei dem Lauf ganz unten unter "Artifacts" die Datei
   `BLELampen-unsigned-ipa` zum Download bereit (enthält `BLELampen.ipa`).
4. Diese IPA ist unsigniert - mit Sideloadly wie gewohnt auf das iPhone installieren,
   Sideloadly übernimmt dabei das Signieren mit deiner Apple-ID.

## Lokal in Xcode öffnen

Alternativ: [XcodeGen](https://github.com/yonaskolb/XcodeGen) lokal installieren,
dann im Projektordner `xcodegen generate` ausführen - das erzeugt
`BLELampen.xcodeproj`, das sich direkt in Xcode öffnen lässt.

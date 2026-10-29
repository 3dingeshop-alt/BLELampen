import Foundation
import Combine

/// Lässt einen Lichteffekt laufen: berechnet in Schleife Farben/Helligkeiten und sendet sie
/// über den BluetoothManager an die ausgewählten Geräte, bis stop() aufgerufen wird.
final class EffectEngine: ObservableObject {
    @Published var isRunning = false
    @Published var activeSceneName: String?

    private var timer: Timer?
    private var tick: Double = 0
    private weak var bt: BluetoothManager?
    private var targetDeviceIDs: [UUID] = []
    private var currentEffect: LightEffect = .rainbow

    func start(scene: LightScene, bt: BluetoothManager, deviceIDs: [UUID]) {
        stop()
        guard !deviceIDs.isEmpty else { return }
        self.bt = bt
        self.targetDeviceIDs = deviceIDs
        self.currentEffect = scene.effect
        self.tick = 0
        self.isRunning = true
        self.activeSceneName = scene.name

        let stepSeconds = Double(scene.stepMillis) / 1000.0
        timer = Timer.scheduledTimer(withTimeInterval: stepSeconds, repeats: true) { [weak self] _ in
            self?.step()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        activeSceneName = nil
    }

    private func step() {
        guard let bt else { return }
        tick += 1
        let devices = bt.connectedDevices.filter { targetDeviceIDs.contains($0.id) }
        guard !devices.isEmpty else { return }

        let (r, g, b, brightnessPercent) = colorForCurrentTick()
        for device in devices {
            let packets = device.commands.colorPackets(r: r, g: g, b: b)
            if !packets.isEmpty { bt.send(packets, to: device) }
        }
        // Helligkeit nur extra senden, wenn der Effekt sich hauptsächlich über
        // Helligkeits-Pulse ausdrückt (Atmen/Blitz/Kerze/Halloween-Flackern).
        switch currentEffect {
        case .breathe, .strobe, .candle, .halloween:
            for device in devices {
                if let data = device.commands.setBrightness(percent: brightnessPercent) {
                    bt.send(data, to: device)
                }
            }
        default:
            break
        }
    }

    private func colorForCurrentTick() -> (UInt8, UInt8, UInt8, Int) {
        switch currentEffect {
        case .rainbow:
            let hue = (tick.truncatingRemainder(dividingBy: 360)) / 360.0
            let (r, g, b) = hsvToRgb(h: hue, s: 1, v: 1)
            return (r, g, b, 100)

        case .colorFade:
            let palette: [(UInt8, UInt8, UInt8)] = [(255, 0, 0), (0, 255, 0), (0, 0, 255), (255, 180, 0), (200, 0, 255)]
            let c = palette[Int(tick) % palette.count]
            return (c.0, c.1, c.2, 100)

        case .breathe:
            let phase = (sin(tick / 10.0) + 1) / 2 // 0...1
            return (255, 180, 80, Int(20 + phase * 80))

        case .strobe:
            let on = Int(tick) % 2 == 0
            return (255, 255, 255, on ? 100 : 0)

        case .candle:
            let flicker = Double.random(in: 0.55...1.0)
            return (255, 140, 40, Int(flicker * 100))

        case .halloween:
            let palette: [(UInt8, UInt8, UInt8)] = [(255, 100, 0), (140, 0, 220)] // Orange / Lila
            let c = palette[Int(tick / 15) % palette.count]
            let flicker = Double.random(in: 0.5...1.0)
            return (c.0, c.1, c.2, Int(flicker * 100))

        case .christmas:
            let palette: [(UInt8, UInt8, UInt8)] = [(255, 0, 0), (0, 160, 0), (255, 200, 0)]
            let c = palette[Int(tick) % palette.count]
            return (c.0, c.1, c.2, 100)
        }
    }

    private func hsvToRgb(h: Double, s: Double, v: Double) -> (UInt8, UInt8, UInt8) {
        let i = Int(h * 6) % 6
        let f = h * 6 - floor(h * 6)
        let p = v * (1 - s)
        let q = v * (1 - f * s)
        let t = v * (1 - (1 - f) * s)
        let (r, g, b): (Double, Double, Double)
        switch i {
        case 0: (r, g, b) = (v, t, p)
        case 1: (r, g, b) = (q, v, p)
        case 2: (r, g, b) = (p, v, t)
        case 3: (r, g, b) = (p, q, v)
        case 4: (r, g, b) = (t, p, v)
        default: (r, g, b) = (v, p, q)
        }
        return (UInt8(r * 255), UInt8(g * 255), UInt8(b * 255))
    }
}

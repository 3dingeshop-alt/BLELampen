import Foundation
import AVFoundation
import Combine

/// Spielt eine vom Nutzer aus der Dateien-App ausgewählte MP3 ab und lässt Helligkeit und
/// Farbe der ausgewählten LED-Geräte im Takt der Lautstärke pulsieren.
final class MusicSyncEngine: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var trackName: String?
    @Published var progress: Double = 0 // 0...1

    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var hue: Double = 0
    private weak var bt: BluetoothManager?
    private var targetDeviceIDs: [UUID] = []

    func load(url: URL) {
        stop()
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let newPlayer = try AVAudioPlayer(data: data)
            newPlayer.isMeteringEnabled = true
            newPlayer.delegate = self
            player = newPlayer
            trackName = url.lastPathComponent
        } catch {
            trackName = nil
        }
    }

    func play(bt: BluetoothManager, deviceIDs: [UUID]) {
        guard let player else { return }
        self.bt = bt
        self.targetDeviceIDs = deviceIDs
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
        isPlaying = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        timer?.invalidate()
        timer = nil
        trackName = nil
        progress = 0
    }

    private func tick() {
        guard let player, let bt else { return }
        player.updateMeters()
        progress = player.duration > 0 ? player.currentTime / player.duration : 0

        // Durchschnittliche Lautstärke (-160...0 dB) grob auf 0...1 normalisieren.
        let db = player.averagePower(forChannel: 0)
        let normalized = max(0, min(1, (db + 50) / 50))
        let brightnessPercent = max(10, Int(normalized * 100))

        hue += 0.004 + Double(normalized) * 0.02
        if hue > 1 { hue -= 1 }
        let (r, g, b) = hsvToRgb(h: hue, s: 0.85, v: 1)

        let devices = bt.connectedDevices.filter { targetDeviceIDs.contains($0.id) }
        for device in devices {
            let packets = device.commands.colorPackets(r: r, g: g, b: b)
            if !packets.isEmpty { bt.send(packets, to: device) }
            if let brightnessData = device.commands.setBrightness(percent: brightnessPercent) {
                bt.send(brightnessData, to: device)
            }
        }

        if !player.isPlaying {
            stop()
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

extension MusicSyncEngine: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in self?.stop() }
    }
}

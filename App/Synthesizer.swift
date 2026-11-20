import Foundation

// An original 108 BPM score. No samples, recordings or external assets.
struct Synthesizer {
    static let sampleRate = 22050.0
    static let bpm = 108.0
    static let beats = 32
    static let progression = [45, 41, 48, 43]
    static let melody = [0, 7, 12, 16, 14, 7, 19, 12, 0, 12, 7, 16, 19, 14, 12, 7]

    static func frequency(_ midi: Int) -> Double {
        440 * pow(2, Double(midi - 69) / 12)
    }

    static func radioSample(time: Double) -> Double {
        let beat = time * bpm / 60
        let chord = Int(beat / 8) % progression.count
        let root = progression[chord]
        let chordProgress = beat.truncatingRemainder(dividingBy: 8) / 8
        let padEnvelope = min(1, chordProgress * 12) * min(1, (1 - chordProgress) * 12)
        var pad = 0.0
        for interval in [0, 7, 12, 16] {
            let phase = time * frequency(root + interval) * 2 * .pi
            pad += (sin(phase) + 0.25 * sin(phase * 2.003)) * 0.024 * padEnvelope
        }
        let step = Int(beat * 2)
        let stepTime = (beat * 2).truncatingRemainder(dividingBy: 1) * 30 / bpm
        let note = root + 12 + melody[step % melody.count]
        let envelope = min(1, stepTime * 120) * exp(-stepTime * 11)
        let leadPhase = stepTime * frequency(note) * 2 * .pi
        let lead = (sin(leadPhase) + 0.23 * sin(leadPhase * 2) + 0.1 * sin(leadPhase * 3)) * envelope * 0.14
        let beatTime = beat.truncatingRemainder(dividingBy: 1) * 60 / bpm
        let bassNote = root - 12 + (Int(beat) % 4 == 3 ? 7 : 0)
        let bass = sin(beatTime * frequency(bassNote) * 2 * .pi) * exp(-beatTime * 5) * 0.16
        let kick = sin(2 * .pi * (46 * beatTime + 4.5 * (1 - exp(-beatTime * 30)))) * exp(-beatTime * 19) * 0.22
        let hatTime = stepTime
        let noise = sin(time * 14539) * sin(time * 19231) * sin(time * 23917)
        let hat = noise * exp(-hatTime * 90) * 0.1
        let snare = Int(beat) % 2 == 1 ? noise * exp(-beatTime * 26) * 0.13 : 0
        return limited(pad + lead + bass + kick + hat + snare, -0.9, 0.9)
    }

    static func engineSample(phase: Double) -> Double {
        sin(phase) * 0.48 + sin(phase * 2) * 0.25 + sin(phase * 3) * 0.13 + sin(phase * 5) * 0.05
    }
}

import Foundation

@main
struct SoundTests {
    static func main() {
        var peak = 0.0
        var energy = 0.0
        for index in 0..<80000 {
            let sample = Synthesizer.radioSample(time: Double(index) / 2000)
            precondition(sample.isFinite && abs(sample) <= 0.9)
            peak = max(peak, abs(sample))
            energy += sample * sample
        }
        precondition(peak > 0.2 && energy / 80000 > 0.001, "Score must contain audible music")
        precondition(abs(Synthesizer.engineSample(phase: 0) - Synthesizer.engineSample(phase: .pi * 124)) < 0.00001)
        precondition(abs(Synthesizer.frequency(69) - 440) < 0.001)
        print("PASS: original score is finite, non-silent and bounded; engine loop is seamless; note tuning")
    }
}

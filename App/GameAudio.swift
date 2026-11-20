import AVFoundation

final class GameAudio {
    private let engine = AVAudioEngine()
    private let motor = AVAudioPlayerNode()
    private let radio = AVAudioPlayerNode()
    private let coast = AVAudioPlayerNode()
    private let tires = AVAudioPlayerNode()
    private let effects = AVAudioPlayerNode()
    private let motorPitch = AVAudioUnitTimePitch()
    private var configured = false
    private var unavailable = false
    private var running = false
    private var buffers: (motor: AVAudioPCMBuffer, radio: AVAudioPCMBuffer,
                          coast: AVAudioPCMBuffer, tires: AVAudioPCMBuffer,
                          door: AVAudioPCMBuffer, impact: AVAudioPCMBuffer)?
    private var preparing = false

    func prepare() {
        guard !preparing, buffers == nil else { return }
        preparing = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let format = AVAudioFormat(standardFormatWithSampleRate: Synthesizer.sampleRate, channels: 1),
                  let motorBuffer = Self.makeMotor(format: format),
                  let radioBuffer = Self.makeRadio(format: format),
                  let coastBuffer = Self.makeSound(format: format, duration: 8, sample: { time in
                      let wave = 0.5 + 0.5 * sin(time * .pi / 4)
                      let noise = sin(time * 2 * .pi * 1837) * sin(time * 2 * .pi * 2939)
                      let foam = sin(time * 2 * .pi * 791) * sin(time * 2 * .pi * 1277)
                      return (noise * 0.13 + foam * 0.1) * (0.3 + wave * 0.7)
                  }),
                  let tireBuffer = Self.makeSound(format: format, duration: 1, sample: { time in
                      let phase = time * 2 * .pi
                      return sin(phase * 740 + sin(phase * 19) * 1.5) * 0.16
                          + sin(phase * 1321) * sin(phase * 1877) * 0.09
                  }),
                  let doorBuffer = Self.makeSound(format: format, duration: 0.25, sample: { time in
                      let body = sin(time * 2 * .pi * 94) * exp(-time * 24)
                      let latch = sin(time * 2 * .pi * 1741) * exp(-time * 75)
                      return (body * 0.45 + latch * 0.15) * min(1, time * 500)
                  }),
                  let impactBuffer = Self.makeSound(format: format, duration: 0.4, sample: { time in
                      let thump = sin(time * 2 * .pi * 57) * exp(-time * 15)
                      let rattle = sin(time * 2 * .pi * 929) * sin(time * 2 * .pi * 1427) * exp(-time * 23)
                      return (thump * 0.45 + rattle * 0.2) * min(1, time * 500)
                  }) else {
                DispatchQueue.main.async { [weak self] in self?.preparing = false }
                return
            }
            DispatchQueue.main.async { [weak self] in
                self?.buffers = (motorBuffer, radioBuffer, coastBuffer, tireBuffer, doorBuffer, impactBuffer)
                self?.preparing = false
            }
        }
    }

    private static func makeMotor(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let count = AVAudioFrameCount(Synthesizer.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = count
        for index in 0..<Int(count) {
            let phase = Double(index) / Synthesizer.sampleRate * 62 * 2 * .pi
            samples[index] = Float(Synthesizer.engineSample(phase: phase))
        }
        return buffer
    }

    private static func makeRadio(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let duration = Double(Synthesizer.beats) * 60 / Synthesizer.bpm
        let count = AVAudioFrameCount(duration * Synthesizer.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = count
        for index in 0..<Int(count) {
            let time = Double(index) / Synthesizer.sampleRate
            let fade = min(1, min(time, duration - time) * 100)
            samples[index] = Float(Synthesizer.radioSample(time: time) * fade)
        }
        return buffer
    }

    private static func makeSound(format: AVAudioFormat, duration: Double,
                                  sample: (Double) -> Double) -> AVAudioPCMBuffer? {
        let count = AVAudioFrameCount(duration * Synthesizer.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = count
        for index in 0..<Int(count) {
            samples[index] = Float(sample(Double(index) / Synthesizer.sampleRate))
        }
        return buffer
    }

    func resume() {
        unavailable = false
        prepare()
    }

    private func startIfReady() {
        guard !unavailable, let buffers = buffers else { return }
        do {
            if !configured {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
                engine.attach(motor)
                engine.attach(radio)
                engine.attach(coast)
                engine.attach(tires)
                engine.attach(effects)
                engine.attach(motorPitch)
                engine.connect(motor, to: motorPitch, format: buffers.motor.format)
                engine.connect(motorPitch, to: engine.mainMixerNode, format: buffers.motor.format)
                engine.connect(radio, to: engine.mainMixerNode, format: buffers.radio.format)
                engine.connect(coast, to: engine.mainMixerNode, format: buffers.coast.format)
                engine.connect(tires, to: engine.mainMixerNode, format: buffers.tires.format)
                engine.connect(effects, to: engine.mainMixerNode, format: buffers.door.format)
                motor.volume = 0
                radio.volume = 0
                coast.volume = 0
                tires.volume = 0
                effects.volume = 0.55
                configured = true
            }
            if !engine.isRunning {
                try AVAudioSession.sharedInstance().setActive(true)
                try engine.start()
            }
            if !running {
                motor.scheduleBuffer(buffers.motor, at: nil, options: .loops)
                radio.scheduleBuffer(buffers.radio, at: nil, options: .loops)
                coast.scheduleBuffer(buffers.coast, at: nil, options: .loops)
                tires.scheduleBuffer(buffers.tires, at: nil, options: .loops)
                motor.play()
                radio.play()
                coast.play()
                tires.play()
                running = true
            }
        } catch {
            unavailable = true
        }
    }

    func update(inCar: Bool, speed: Double, throttle: Double, radioEnabled: Bool, soundEnabled: Bool,
                kind: CarKind? = nil, tireSlip: Double = 0, nearBeach: Bool = false) {
        guard soundEnabled else {
            if running { suspend() }
            return
        }
        startIfReady()
        guard running else { return }
        let factor = Float(min(speed / (kind?.maximumSpeed ?? 51), 1))
        let targetMotor: Float = soundEnabled && inCar ? 0.06 + factor * 0.11 + Float(throttle) * 0.035 : 0
        let targetRadio: Float = soundEnabled && inCar && radioEnabled ? 0.64 : 0
        motor.volume += (targetMotor - motor.volume) * 0.12
        radio.volume += (targetRadio - radio.volume) * 0.08
        let targetCoast: Float = (nearBeach ? 0.38 : 0.09) * (inCar ? 0.3 : 1)
        coast.volume += (targetCoast - coast.volume) * 0.04
        let targetTires: Float = inCar ? Float(tireSlip) * 0.5 : 0
        tires.volume += (targetTires - tires.volume) * 0.15
        let voice: Float = kind == .pickup ? 0.72 : (kind == .sedan ? 0.82 : 0.95)
        motorPitch.rate = voice + factor * 2.1
        motorPitch.pitch = factor * 450 + Float(throttle) * 90
    }

    func playDoor() {
        startIfReady()
        guard running, let buffers = buffers else { return }
        effects.stop()
        effects.scheduleBuffer(buffers.door, at: nil, options: [])
        effects.play()
    }

    func playImpact() {
        startIfReady()
        guard running, let buffers = buffers else { return }
        effects.stop()
        effects.scheduleBuffer(buffers.impact, at: nil, options: [])
        effects.play()
    }

    func suspend() {
        guard configured else { return }
        motor.stop()
        radio.stop()
        coast.stop()
        tires.stop()
        effects.stop()
        motor.volume = 0
        radio.volume = 0
        coast.volume = 0
        tires.volume = 0
        engine.pause()
        running = false
    }
}

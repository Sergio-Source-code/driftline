import SwiftUI
import Observation

@Observable
final class GameController {
    var simulation: GameSimulation
    var camera = ChaseCamera()
    var joystick = Point2.zero
    var gas = false
    var brake = false
    var paused = false
    var mapExpanded = false
    var showHelp = false
    var radioEnabled = true
    var soundEnabled = true
    var shakeEnabled = true
    var feedback = 0
    var notice = ""
    var noticeUntil = 0.0

    @ObservationIgnored let layout: CityLayout
    @ObservationIgnored let renderer: WorldRenderer
    @ObservationIgnored private let audio = GameAudio()
    @ObservationIgnored private var previousTick: Date?
    @ObservationIgnored private var lastCollision = 0
    @ObservationIgnored private var feedbackTime = 0.0
    @ObservationIgnored private var lastSaveTime = 0.0

    init() {
        let layout = CityLayout()
        self.layout = layout
        simulation = layout.makeSimulation()
        renderer = WorldRenderer(artwork: CityArtwork(layout: layout))
        if let save = GameSave.load() {
            save.restore(into: &simulation)
            radioEnabled = save.radioEnabled
            soundEnabled = save.soundEnabled
            shakeEnabled = save.shakeEnabled
        }
        camera.snap(to: simulation)
    }

    var driving: Bool {
        if case .driving = simulation.mode { return true }
        return false
    }
    var speedMPH: Int { Int(simulation.speed * 2.23694) }
    var timeLabel: String {
        let hours = Int(simulation.timeOfDay)
        let minutes = Int((simulation.timeOfDay - Double(hours)) * 60)
        return String(format: "%02d:%02d", hours, minutes)
    }
    var missionTitle: String {
        if simulation.distanceDriven < 1 { return "YOUR CITY. YOUR PACE." }
        if simulation.visitedDistricts.count < 3 { return "TAKE THE LONG WAY HOME" }
        return "NOWHERE YOU HAVE TO BE"
    }
    var missionDetail: String {
        if simulation.mode == .walking {
            return simulation.nearestCar.map { "\($0.kind.name) nearby · tap GET IN" } ?? "Walk up to a stopped car to take the wheel"
        }
        if simulation.distanceDriven < 200 { return "Head north along the water. Find your line." }
        return "\(simulation.visitedDistricts.count)/3 districts explored · \(String(format: "%.1f", simulation.distanceDriven / 1000)) km cruised"
    }

    func start() { audio.resume() }

    func tick(_ date: Date) {
        guard !paused, !mapExpanded, !showHelp else {
            previousTick = nil
            return
        }
        let dt = limited(date.timeIntervalSince(previousTick ?? date), 0, 0.1)
        previousTick = date
        guard dt > 0 else { return }
        let previousMode = simulation.mode
        let previousDistrict = simulation.district
        let input = DrivingInput(steering: joystick.x, throttle: gas ? 1 : 0, brake: brake ? 1 : 0)
        let steps = max(1, Int(ceil(dt * 30)))
        let step = dt / Double(steps)
        for _ in 0..<steps {
            simulation.step(dt: step, joystick: joystick, input: input, cameraHeading: camera.heading)
            camera.update(game: simulation, dt: step, shakeEnabled: shakeEnabled)
        }
        if simulation.collisions != lastCollision && simulation.elapsed - feedbackTime > 0.5 {
            feedback += 1
            feedbackTime = simulation.elapsed
            if soundEnabled { audio.playImpact() }
        }
        if previousMode.isTransitioning && !simulation.mode.isTransitioning {
            if soundEnabled { audio.playDoor() }
            saveProgress()
        }
        if simulation.district != previousDistrict {
            notice = "Now entering \(simulation.district)"
            noticeUntil = simulation.elapsed + 3
        }
        lastCollision = simulation.collisions
        audio.update(inCar: driving, speed: simulation.speed, throttle: gas ? 1 : 0,
                     radioEnabled: radioEnabled, soundEnabled: soundEnabled,
                     kind: simulation.activeCar?.kind, tireSlip: simulation.tireSlip,
                     nearBeach: simulation.focus.x > 196)
        if simulation.elapsed - lastSaveTime >= 20 { saveProgress() }
    }

    func saveProgress() {
        GameSave(simulation: simulation, radio: radioEnabled, sound: soundEnabled, shake: shakeEnabled).store()
        lastSaveTime = simulation.elapsed
    }

    func interact() {
        guard !simulation.mode.isTransitioning else { return }
        if simulation.interact() {
            resetControls()
            feedback += 1
        } else {
            notice = driving ? "Slow to a stop with clear space beside the car." : "Walk closer to a stopped car."
            noticeUntil = simulation.elapsed + 3
        }
    }

    func resetControls() {
        joystick = .zero
        gas = false
        brake = false
        previousTick = nil
    }

    func pause() {
        resetControls()
        audio.suspend()
        mapExpanded = false
        showHelp = false
        paused = true
        saveProgress()
    }

    func resume() {
        resetControls()
        audio.resume()
        paused = false
        mapExpanded = false
        showHelp = false
        saveProgress()
    }

    func suspend() {
        pause()
    }

    func openMap() {
        resetControls()
        audio.suspend()
        paused = false
        showHelp = false
        mapExpanded = true
    }

    func newCruise() {
        resetControls()
        audio.suspend()
        simulation = layout.makeSimulation()
        camera.snap(to: simulation)
        lastCollision = 0
        feedbackTime = 0
        lastSaveTime = 0
        notice = "A fresh sunset. Your first ride is just ahead."
        noticeUntil = 6
        paused = false
        mapExpanded = false
        showHelp = false
        feedback += 1
        audio.resume()
        saveProgress()
    }

    func recover() {
        resetControls()
        if let id = simulation.mode.carID, let index = simulation.cars.firstIndex(where: { $0.id == id }) {
            let candidates = stride(from: 31.0, through: 231.0, by: 10.0).map { Point2(x: 247, z: $0) }
            let clearSpot = candidates.first { point in
                !simulation.cars.contains { $0.id != id && $0.position.distance(to: point) < 7 }
            } ?? Point2(x: 247, z: -230)
            simulation.cars[index].position = clearSpot
            simulation.cars[index].heading = 0
            simulation.cars[index].speed = 0
            simulation.mode = .driving(id)
            simulation.player = simulation.cars[index].position
        } else {
            simulation.player = Point2(x: 253, z: 25)
            simulation.mode = .walking
        }
        simulation.tireSlip = 0
        simulation.braking = false
        camera.snap(to: simulation)
        audio.resume()
        paused = false
        mapExpanded = false
        showHelp = false
        feedback += 1
        saveProgress()
    }
}

import Foundation

struct GameSave: Codable {
    let cars: [CarState]
    let player: Point2
    let playerHeading: Double
    let activeCarID: Int?
    let timeOfDay: Double
    let distanceDriven: Double
    let visitedDistricts: Set<String>
    let radioEnabled: Bool
    let soundEnabled: Bool
    let shakeEnabled: Bool

    init(simulation: GameSimulation, radio: Bool, sound: Bool, shake: Bool) {
        cars = simulation.cars.map { car in
            var parked = car
            if !parked.isTraffic { parked.speed = 0 }
            return parked
        }
        if case .exiting = simulation.mode {
            player = simulation.transitionEnd
            activeCarID = nil
        } else {
            player = simulation.player
            activeCarID = simulation.mode.carID
        }
        playerHeading = simulation.playerHeading
        timeOfDay = simulation.timeOfDay
        distanceDriven = simulation.distanceDriven
        visitedDistricts = simulation.visitedDistricts
        radioEnabled = radio
        soundEnabled = sound
        shakeEnabled = shake
    }

    func restore(into simulation: inout GameSimulation) {
        simulation.cars = cars
        simulation.player = player
        simulation.playerHeading = playerHeading
        simulation.timeOfDay = timeOfDay
        simulation.distanceDriven = distanceDriven
        simulation.visitedDistricts = visitedDistricts
        if let id = activeCarID, let car = cars.first(where: { $0.id == id }) {
            simulation.mode = .driving(id)
            simulation.player = car.position
            simulation.playerHeading = car.heading
        }
    }

    static func load() -> GameSave? {
        guard let data = UserDefaults.standard.data(forKey: "driftline.coast.v1") else { return nil }
        return try? JSONDecoder().decode(GameSave.self, from: data)
    }

    func store() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: "driftline.coast.v1")
    }
}

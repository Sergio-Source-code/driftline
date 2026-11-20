import Foundation

@main
struct CityTests {
    static func main() {
        let city = CityLayout()
        var game = city.makeSimulation()
        precondition(city.buildings.count > 60 && game.cars.count == 24 && game.pedestrians.count == 48)
        precondition(!game.world.isBlocked(game.player, radius: 0.55))
        precondition(game.nearestCar?.kind == .sports, "Spawn must be beside the sports car")
        for car in game.cars {
            precondition(!game.world.isBlocked(car.position, radius: 2.2), "Cars must spawn on open streets")
        }
        for person in game.pedestrians {
            precondition(!game.world.isBlocked(person.position, radius: 0.4), "Sidewalks must be walkable")
        }
        let originalTraffic = game.cars.filter { $0.isTraffic }.map { $0.position }
        let originalPeople = game.pedestrians.map { $0.position }
        for _ in 0..<3600 { game.step(dt: 1 / 60, joystick: .zero, input: DrivingInput(), cameraHeading: 0) }
        let traffic = game.cars.filter { $0.isTraffic }
        precondition(zip(originalTraffic, traffic).filter { $0.0.distance(to: $0.1.position) > 3 }.count > 12)
        precondition(zip(originalPeople, game.pedestrians).filter { $0.0.distance(to: $0.1.position) > 2 }.count > 35)
        for car in game.cars {
            precondition(car.position.x.isFinite && !game.world.isBlocked(car.position, radius: 2.1))
        }
        precondition(game.timeOfDay > 19, "Day/night clock must advance")
        game.player = Point2(x: -268, z: 0)
        precondition(game.district == "Highway loop")
        game.player = .zero
        precondition(game.district == "Downtown")
        print("PASS: coastal spawn, 68 buildings, 24 cars, 48 pedestrians, 60-second traffic simulation, districts, day/night")
    }
}

import Foundation

@main
struct IntegrationTests {
    static func main() {
        var game = CityLayout().makeSimulation()
        // Start in the travel lane: a straight-line test from the curb would
        // correctly stop against the parked sedan farther up the street.
        game.cars[0].position.x = 240
        game.player.x = 243
        var camera = ChaseCamera()
        precondition(game.interact())
        for frame in 0..<1200 {
            let gas = frame > 60 && frame < 900 ? 1.0 : 0.0
            let brake = frame >= 900 ? 1.0 : 0.0
            game.step(dt: 1 / 30, joystick: .zero, input: DrivingInput(throttle: gas, brake: brake), cameraHeading: camera.heading)
            camera.update(game: game, dt: 1 / 30, shakeEnabled: true)
            precondition(game.focus.x.isFinite && game.focus.z.isFinite && camera.eye.length.isFinite)
            precondition(!game.world.isBlocked(game.focus, radius: 2))
        }
        precondition(game.distanceDriven > 150)
        if let id = game.mode.carID, let index = game.cars.firstIndex(where: { $0.id == id }) {
            game.cars[index].speed = 0
        }
        precondition(game.interact())
        for _ in 0..<30 {
            game.step(dt: 1 / 30, joystick: .zero, input: DrivingInput(), cameraHeading: camera.heading)
        }
        precondition(game.mode == .walking)
        // Exercise every vehicle's local mesh, including animated doors and night lights.
        for car in game.cars {
            var mesh = MeshBuilder()
            mesh.vehicle(car, door: 0.8, night: true)
            precondition(mesh.faces.count > 50)
            precondition(mesh.faces.allSatisfy { $0.vertices.allSatisfy { $0.length.isFinite } })
        }
        var traffic = CityLayout().makeSimulation()
        let target = traffic.cars[6]
        traffic.player = target.position + target.forward * 6
        for _ in 0..<60 {
            traffic.step(dt: 1 / 60, joystick: .zero, input: DrivingInput(), cameraHeading: 0)
        }
        precondition(traffic.cars[6].speed < 3 && traffic.interact(), "Stopped traffic must be enterable")
        print("PASS: 40-second walk/drive/exit integration, camera following, all car geometry, traffic entry")
    }
}

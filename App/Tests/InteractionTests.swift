import Foundation

@main
struct InteractionTests {
    static func main() {
        var game = GameSimulation()
        game.player = Point2(x: 3.5, z: 0)
        game.cars = [CarState(id: 0, kind: .sports, position: .zero, heading: 0)]
        precondition(game.mode == .walking && game.canInteract)
        precondition(game.interact() && game.mode == .entering(0))
        for _ in 0..<60 { game.step(dt: 1 / 60, joystick: .zero, input: DrivingInput(), cameraHeading: 0) }
        precondition(game.mode == .driving(0), "Entry animation must finish in the car")
        game.cars[0].speed = 20
        precondition(!game.interact(), "Exit must be blocked at speed")
        game.cars[0].speed = 0
        precondition(game.interact())
        for _ in 0..<60 { game.step(dt: 1 / 60, joystick: .zero, input: DrivingInput(), cameraHeading: 0) }
        precondition(game.mode == .walking && game.player.distance(to: .zero) > 3)
        let before = game.player
        for _ in 0..<60 { game.step(dt: 1 / 60, joystick: Point2(x: 0, z: 1), input: DrivingInput(), cameraHeading: 0) }
        precondition(game.player.distance(to: before) > 5, "Joystick must walk relative to camera")
        game.player = Point2(x: 100, z: 100)
        precondition(!game.interact(), "Distant cars must not be enterable")
        for kind in CarKind.allCases {
            game.cars = [CarState(id: 2, kind: kind, position: game.player + Point2(x: 4, z: 0), heading: 0)]
            precondition(game.interact(), "Every car type must be enterable")
            game.mode = .walking
        }
        print("PASS: foot spawn, proximity, animated entry/exit, safe-speed exit, walking, every car type")
    }
}

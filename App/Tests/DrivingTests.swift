import Foundation

@main
struct DrivingTests {
    static func main() {
        var car = CarState(id: 0, kind: .sports, position: .zero, heading: 0)
        let world = DrivingWorld()
        for _ in 0..<120 {
            world.move(&car, input: DrivingInput(throttle: 1), dt: 1 / 60)
        }
        precondition(car.speed > 30 && car.position.z > 20, "Accelerator must move the car forward")
        let before = car.speed
        for _ in 0..<30 {
            world.move(&car, input: DrivingInput(brake: 1), dt: 1 / 60)
        }
        precondition(car.speed < before - 10, "Brake must slow the car")
        for _ in 0..<180 {
            world.move(&car, input: DrivingInput(brake: 1), dt: 1 / 60)
        }
        precondition(car.speed < 0 && car.speed >= -9, "Reverse must be bounded")
        car.speed = 20
        let heading = car.heading
        for _ in 0..<45 {
            world.move(&car, input: DrivingInput(steering: 1, throttle: 1), dt: 1 / 60)
        }
        precondition(car.heading > heading + 0.2, "Steering must turn a moving car")
        for kind in CarKind.allCases {
            var test = CarState(id: 1, kind: kind, position: .zero, heading: 0)
            for _ in 0..<1800 { test.drive(DrivingInput(throttle: 1), dt: 1 / 60) }
            precondition(test.speed <= kind.maximumSpeed, "Top speed must be capped")
        }
        var blockedWorld = DrivingWorld()
        blockedWorld.obstacles = [WorldObstacle(center: Point2(x: 0, z: 8), halfWidth: 5, halfDepth: 2)]
        car = CarState(id: 0, kind: .sedan, position: .zero, heading: 0, speed: 20)
        var hit = false
        for _ in 0..<60 {
            hit = blockedWorld.move(&car, input: DrivingInput(throttle: 1), dt: 1 / 60) || hit
        }
        precondition(hit && car.position.z < 4, "Buildings must stop cars")
        print("PASS: acceleration, braking, reverse, steering, three speed limits, collision")
    }
}

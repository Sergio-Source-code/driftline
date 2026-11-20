import Foundation

struct Point2: Equatable, Codable {
    var x: Double
    var z: Double

    static let zero = Point2(x: 0, z: 0)
    static func + (lhs: Point2, rhs: Point2) -> Point2 {
        Point2(x: lhs.x + rhs.x, z: lhs.z + rhs.z)
    }
    static func - (lhs: Point2, rhs: Point2) -> Point2 {
        Point2(x: lhs.x - rhs.x, z: lhs.z - rhs.z)
    }
    static func * (lhs: Point2, rhs: Double) -> Point2 {
        Point2(x: lhs.x * rhs, z: lhs.z * rhs)
    }
    var length: Double { hypot(x, z) }
    func distance(to other: Point2) -> Double { (self - other).length }
    var normalized: Point2 { length > 0.001 ? self * (1 / length) : .zero }
}

func limited(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
    min(upper, max(lower, value))
}

func angleDelta(from: Double, to: Double) -> Double {
    atan2(sin(to - from), cos(to - from))
}

enum CarKind: Int, CaseIterable, Codable {
    case sports, sedan, pickup

    var name: String {
        switch self {
        case .sports: return "Solstice GT"
        case .sedan: return "Vela S4"
        case .pickup: return "Mesa Trail"
        }
    }
    var maximumSpeed: Double {
        switch self {
        case .sports: return 51
        case .sedan: return 39
        case .pickup: return 34
        }
    }
    var acceleration: Double {
        switch self {
        case .sports: return 17
        case .sedan: return 12
        case .pickup: return 10
        }
    }
    var turning: Double {
        switch self {
        case .sports: return 1.95
        case .sedan: return 1.65
        case .pickup: return 1.4
        }
    }
    var length: Double { self == .pickup ? 5.5 : 4.8 }
}

struct DrivingInput {
    var steering = 0.0
    var throttle = 0.0
    var brake = 0.0
}

struct CarState: Identifiable, Codable {
    let id: Int
    let kind: CarKind
    var position: Point2
    var heading: Double
    var speed = 0.0
    var colorIndex = 0
    var route: [Point2] = []
    var waypoint = 0
    var cruiseSpeed = 10.0
    var isTraffic = false
    var wheelRotation = 0.0
    var steeringAngle = 0.0

    var forward: Point2 { Point2(x: sin(heading), z: cos(heading)) }

    mutating func drive(_ input: DrivingInput, dt: Double) {
        let throttle = limited(input.throttle, 0, 1)
        let brake = limited(input.brake, 0, 1)
        if throttle > 0 && brake == 0 {
            speed += kind.acceleration * throttle * dt
        } else if brake == 0 {
            let drag = (1.1 + abs(speed) * 0.035) * dt
            speed = abs(speed) <= drag ? 0 : speed - (speed > 0 ? drag : -drag)
        }
        // Holding the brake after stopping engages a gentle reverse.
        if brake > 0 {
            speed -= (speed > 0.2 ? 29 : 7) * brake * dt
        }
        speed = limited(speed, -9, kind.maximumSpeed)
        let steer = limited(input.steering, -1, 1)
        let grip = min(abs(speed) / 7, 1) / (1 + abs(speed) * 0.018)
        heading += steer * kind.turning * grip * (speed >= 0 ? 1 : -1) * dt
        steeringAngle += (steer * 0.4 - steeringAngle) * min(1, dt * 12)
        position = position + forward * (speed * dt)
        wheelRotation += speed * dt / 0.42
    }
}

struct WorldObstacle {
    let center: Point2
    let halfWidth: Double
    let halfDepth: Double

    func contains(_ point: Point2, padding: Double) -> Bool {
        abs(point.x - center.x) < halfWidth + padding &&
        abs(point.z - center.z) < halfDepth + padding
    }
}

struct DrivingWorld {
    static let limit = 281.0
    var obstacles: [WorldObstacle] = []

    func isBlocked(_ point: Point2, radius: Double) -> Bool {
        point.x < -Self.limit + radius || point.x > Self.limit - radius ||
        abs(point.z) > Self.limit - radius ||
        obstacles.contains { $0.contains(point, padding: radius) }
    }

    @discardableResult
    func move(_ car: inout CarState, input: DrivingInput, dt: Double) -> Bool {
        let previous = car.position
        car.drive(input, dt: min(dt, 1.0 / 30.0))
        if isBlocked(car.position, radius: 2.2) {
            car.position = previous
            car.speed *= -0.18
            return true
        }
        return false
    }
}

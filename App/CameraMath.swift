import Foundation

struct Vector3 {
    var x: Double
    var y: Double
    var z: Double

    static let zero = Vector3(x: 0, y: 0, z: 0)
    static func + (a: Vector3, b: Vector3) -> Vector3 { Vector3(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z) }
    static func - (a: Vector3, b: Vector3) -> Vector3 { Vector3(x: a.x - b.x, y: a.y - b.y, z: a.z - b.z) }
    static func * (a: Vector3, b: Double) -> Vector3 { Vector3(x: a.x * b, y: a.y * b, z: a.z * b) }
    func dot(_ b: Vector3) -> Double { x * b.x + y * b.y + z * b.z }
    func cross(_ b: Vector3) -> Vector3 {
        Vector3(x: y * b.z - z * b.y, y: z * b.x - x * b.z, z: x * b.y - y * b.x)
    }
    var length: Double { sqrt(dot(self)) }
    var normalized: Vector3 { length > 0.0001 ? self * (1 / length) : .zero }
}

struct ChaseCamera {
    var eye = Vector3(x: 253, y: 5.7, z: 16)
    var target = Vector3(x: 253, y: 1.1, z: 31)
    var heading = 0.0
    var fieldOfView = 58.0
    var shake = 0.0

    mutating func snap(to game: GameSimulation) {
        heading = game.activeCar?.heading ?? game.playerHeading
        let focus = game.focus
        let distance = game.activeCar == nil ? 8.4 : 10.5
        eye = Vector3(x: focus.x - sin(heading) * distance, y: 5.8,
                      z: focus.z - cos(heading) * distance)
        target = Vector3(x: focus.x + sin(heading) * 4.2, y: 1.25,
                         z: focus.z + cos(heading) * 4.2)
        fieldOfView = 58
        shake = 0
    }

    mutating func update(game: GameSimulation, dt: Double, shakeEnabled: Bool) {
        let driving = game.mode.carID != nil
        let speedFactor = min(game.speed / 48, 1)
        if let car = game.activeCar {
            heading += angleDelta(from: heading, to: car.heading) * min(1, dt * 4.2)
        }
        let forward = Point2(x: sin(heading), z: cos(heading))
        let distance = driving ? 10.5 + speedFactor * 5.5 : 8.4
        let focus = game.focus
        let desiredEye = Vector3(
            x: focus.x - forward.x * distance,
            y: driving ? 5.8 + speedFactor * 1.7 : 5.6,
            z: focus.z - forward.z * distance
        )
        let desiredTarget = Vector3(
            x: focus.x + forward.x * (driving ? 5.0 : 4.2),
            y: 1.25, z: focus.z + forward.z * (driving ? 5.0 : 4.2)
        )
        let blend = 1 - exp(-dt * 7)
        eye = eye + (desiredEye - eye) * blend
        target = target + (desiredTarget - target) * blend
        fieldOfView += ((driving ? 59 + speedFactor * 13 : 58) - fieldOfView) * blend
        shake = shakeEnabled ? max(0, speedFactor - 0.45) * 0.11 * sin(game.elapsed * 43) : 0
        // Trace from the player to the eye, not just the eye's final position.
        let anchor = Vector3(x: focus.x, y: 3.2, z: focus.z)
        let offset = eye - anchor
        for index in 1...24 {
            let fraction = Double(index) / 24
            let candidate = anchor + offset * fraction
            if game.world.isBlocked(Point2(x: candidate.x, z: candidate.z), radius: 0.7) {
                eye = anchor + offset * (Double(index - 1) / 24)
                break
            }
        }
    }
}

struct CameraProjection {
    let camera: ChaseCamera
    let width: Double
    let height: Double
    let forward: Vector3
    let right: Vector3
    let up: Vector3
    let focal: Double

    init(camera: ChaseCamera, width: Double, height: Double) {
        self.camera = camera
        self.width = width
        self.height = height
        forward = (camera.target - camera.eye).normalized
        right = Vector3(x: 0, y: 1, z: 0).cross(forward).normalized
        up = forward.cross(right)
        focal = height / (2 * tan(camera.fieldOfView * .pi / 360))
    }

    func cameraSpace(_ world: Vector3) -> Vector3 {
        let relative = world - camera.eye
        return Vector3(x: relative.dot(right) + camera.shake, y: relative.dot(up), z: relative.dot(forward))
    }

    func screenPoint(_ point: Vector3) -> Point2 {
        Point2(x: width / 2 + point.x * focal / point.z,
               z: height * 0.5 - point.y * focal / point.z)
    }

    func polygon(_ vertices: [Vector3]) -> [Point2] {
        let input = vertices.map { cameraSpace($0) }
        guard !input.isEmpty else { return [] }
        var clipped: [Vector3] = []
        var previous = input[input.count - 1]
        for current in input {
            let currentInside = current.z >= 0.4
            let previousInside = previous.z >= 0.4
            if currentInside != previousInside {
                let amount = (0.4 - previous.z) / (current.z - previous.z)
                clipped.append(previous + (current - previous) * amount)
            }
            if currentInside { clipped.append(current) }
            previous = current
        }
        guard clipped.count >= 3 else { return [] }
        let points = clipped.map { screenPoint($0) }
        if points.allSatisfy({ $0.x < -20 }) || points.allSatisfy({ $0.x > width + 20 }) ||
            points.allSatisfy({ $0.z < -20 }) || points.allSatisfy({ $0.z > height + 20 }) { return [] }
        return points
    }
}

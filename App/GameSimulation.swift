import Foundation

enum TravelMode: Equatable {
    case walking
    case entering(Int)
    case driving(Int)
    case exiting(Int)

    var carID: Int? {
        switch self {
        case .walking: return nil
        case .entering(let id), .driving(let id), .exiting(let id): return id
        }
    }
    var isTransitioning: Bool {
        switch self {
        case .entering, .exiting: return true
        default: return false
        }
    }
}

struct Pedestrian: Identifiable {
    let id: Int
    var position: Point2
    var heading: Double
    var route: [Point2]
    var waypoint: Int
    var stride = 0.0
    var pace = 1.4
}

struct TireMark {
    let start: Point2
    let end: Point2
    let created: Double
}

struct GameSimulation {
    var world = DrivingWorld()
    var cars: [CarState] = []
    var pedestrians: [Pedestrian] = []
    var player = Point2(x: 248, z: 25)
    var playerHeading = 0.0
    var walkStride = 0.0
    var walkingSpeed = 0.0
    var mode: TravelMode = .walking
    var transitionProgress = 0.0
    var transitionStart = Point2.zero
    var transitionEnd = Point2.zero
    var transitionDoor = Point2.zero
    var transitionSide = -1.0
    var elapsed = 0.0
    var timeOfDay = 17.6
    var collisions = 0
    var distanceDriven = 0.0
    var visitedDistricts: Set<String> = ["Beach strip"]
    var tireMarks: [TireMark] = []
    var tireSlip = 0.0
    var braking = false

    var activeCar: CarState? {
        guard let id = mode.carID else { return nil }
        return cars.first { $0.id == id }
    }
    var focus: Point2 {
        guard let car = activeCar else { return player }
        let progress = transitionProgress * transitionProgress * (3 - 2 * transitionProgress)
        switch mode {
        case .entering: return transitionStart + (car.position - transitionStart) * progress
        case .exiting: return car.position + (transitionEnd - car.position) * progress
        default: return car.position
        }
    }
    var speed: Double { activeCar.map { abs($0.speed) } ?? 0 }
    var district: String {
        let point = focus
        if abs(point.z) > 251 || point.x < -251 { return "Highway loop" }
        return point.x > 196 ? "Beach strip" : "Downtown"
    }
    var nearestCar: CarState? {
        cars.filter { $0.position.distance(to: player) < 9 && abs($0.speed) < 3 }
            .min { $0.position.distance(to: player) < $1.position.distance(to: player) }
    }
    var interactionTitle: String {
        switch mode {
        case .walking: return nearestCar == nil ? "FIND A CAR" : "GET IN"
        case .driving: return speed >= 4 ? "SLOW DOWN" : "GET OUT"
        case .entering: return "GETTING IN"
        case .exiting: return "GETTING OUT"
        }
    }
    var canInteract: Bool {
        switch mode {
        case .walking: return nearestCar != nil
        case .driving: return speed < 4
        default: return false
        }
    }

    @discardableResult
    mutating func interact() -> Bool {
        switch mode {
        case .walking:
            guard let car = nearestCar,
                  let index = cars.firstIndex(where: { $0.id == car.id }) else { return false }
            let side = Point2(x: cos(car.heading), z: -sin(car.heading))
            let doors = [-1.0, 1.0].map { sign in
                (sign: sign, point: car.position + side * (sign * 3.1))
            }.sorted { $0.point.distance(to: player) < $1.point.distance(to: player) }
            guard let door = doors.first(where: { option in
                (1...12).allSatisfy { sample in
                    let point = player + (option.point - player) * (Double(sample) / 12)
                    return canWalk(to: point)
                }
            }) else { return false }
            cars[index].isTraffic = false
            cars[index].speed = 0
            transitionStart = player
            transitionDoor = door.point
            transitionSide = door.sign
            transitionEnd = car.position
            transitionProgress = 0
            mode = .entering(car.id)
            return true
        case .driving(let id):
            guard speed < 4,
                  let index = cars.firstIndex(where: { $0.id == id }) else { return false }
            let car = cars[index]
            let side = Point2(x: cos(car.heading), z: -sin(car.heading))
            let options = [car.position - side * 3.3, car.position + side * 3.3,
                           car.position - car.forward * 4.5]
            guard let exit = options.first(where: { candidate in
                !world.isBlocked(candidate, radius: 0.6) &&
                !cars.contains { $0.id != id && $0.position.distance(to: candidate) < 3 }
            }) else { return false }
            cars[index].speed = 0
            transitionStart = car.position
            transitionEnd = exit
            transitionDoor = exit
            let offset = exit - car.position
            transitionSide = offset.x * side.x + offset.z * side.z > 0 ? 1 : -1
            transitionProgress = 0
            mode = .exiting(id)
            return true
        default: return false
        }
    }

    mutating func step(dt rawDT: Double, joystick: Point2, input: DrivingInput, cameraHeading: Double) {
        let dt = limited(rawDT, 0, 1 / 30)
        elapsed += dt
        timeOfDay = (timeOfDay + dt * 24 / 720).truncatingRemainder(dividingBy: 24)
        walkingSpeed = 0
        tireSlip = 0
        braking = false
        let oldestMark = elapsed - 12
        tireMarks.removeAll { $0.created < oldestMark }
        switch mode {
        case .walking:
            let right = Point2(x: cos(cameraHeading), z: -sin(cameraHeading))
            let forward = Point2(x: sin(cameraHeading), z: cos(cameraHeading))
            let movement = right * joystick.x + forward * joystick.z
            let velocity = movement.length > 1 ? movement.normalized : movement
            let proposed = player + velocity * (5.6 * dt)
            if canWalk(to: proposed) {
                player = proposed
                walkingSpeed = velocity.length * 5.6
                walkStride += walkingSpeed * dt * 2.6
            } else {
                let slideX = Point2(x: proposed.x, z: player.z)
                let slideZ = Point2(x: player.x, z: proposed.z)
                let previous = player
                if canWalk(to: slideX) { player = slideX }
                if canWalk(to: slideZ) { player = slideZ }
                let distance = player.distance(to: previous)
                walkingSpeed = dt > 0 ? distance / dt : 0
                walkStride += distance * 2.6
            }
            if velocity.length > 0.08 {
                let target = atan2(velocity.x, velocity.z)
                playerHeading += angleDelta(from: playerHeading, to: target) * min(1, dt * 12)
            }
        case .driving(let id):
            if let index = cars.firstIndex(where: { $0.id == id }) {
                let previousCar = cars[index]
                let previous = previousCar.position
                braking = input.brake > 0 && previousCar.speed > 0.2
                if world.move(&cars[index], input: input, dt: dt) { collisions += 1 }
                for other in cars where other.id != id {
                    if cars[index].position.distance(to: other.position) < 4.3 {
                        cars[index].position = previous
                        cars[index].speed *= -0.2
                        collisions += 1
                        break
                    }
                }
                let car = cars[index]
                let distance = car.position.distance(to: previous)
                distanceDriven += distance
                let cornering = abs(input.steering) * limited((abs(car.speed) - 13) / 23, 0, 1)
                let stopping = braking ? limited((car.speed - 8) / 20, 0, 1) : 0
                tireSlip = max(cornering, stopping)
                if tireSlip > 0.38 && distance > 0.05 {
                    let oldSide = Point2(x: cos(previousCar.heading), z: -sin(previousCar.heading))
                    let newSide = Point2(x: cos(car.heading), z: -sin(car.heading))
                    for side in [-1.0, 1.0] {
                        tireMarks.append(TireMark(
                            start: previous - previousCar.forward * (car.kind.length * 0.32) + oldSide * side,
                            end: car.position - car.forward * (car.kind.length * 0.32) + newSide * side,
                            created: elapsed
                        ))
                    }
                    if tireMarks.count > 280 { tireMarks.removeFirst(tireMarks.count - 280) }
                }
                player = cars[index].position
                playerHeading = cars[index].heading
            }
        case .entering(let id), .exiting(let id):
            transitionProgress = min(1, transitionProgress + dt / 0.85)
            let previous = player
            if case .entering = mode {
                if transitionProgress < 0.6 {
                    let phase = transitionProgress / 0.6
                    let eased = phase * phase * (3 - 2 * phase)
                    player = transitionStart + (transitionDoor - transitionStart) * eased
                } else {
                    let phase = (transitionProgress - 0.6) / 0.4
                    let eased = phase * phase * (3 - 2 * phase)
                    player = transitionDoor + (transitionEnd - transitionDoor) * eased
                }
            } else {
                let eased = transitionProgress * transitionProgress * (3 - 2 * transitionProgress)
                player = transitionStart + (transitionEnd - transitionStart) * eased
            }
            walkStride += player.distance(to: previous) * 2.6
            if let car = cars.first(where: { $0.id == id }) {
                playerHeading = car.heading
            }
            if transitionProgress >= 1 {
                if case .entering = mode {
                    mode = .driving(id)
                    player = activeCar?.position ?? player
                } else {
                    player = transitionEnd
                    mode = .walking
                }
            }
        }
        updateTraffic(dt: dt)
        updatePedestrians(dt: dt)
        visitedDistricts.insert(district)
    }

    func canWalk(to point: Point2) -> Bool {
        !world.isBlocked(point, radius: 0.55) &&
        !cars.contains { $0.position.distance(to: point) < 2.1 }
    }

    mutating func updateTraffic(dt: Double) {
        for index in cars.indices {
            guard cars[index].isTraffic, !cars[index].route.isEmpty else { continue }
            var target = cars[index].route[cars[index].waypoint]
            if target.distance(to: cars[index].position) < 4 {
                cars[index].waypoint = (cars[index].waypoint + 1) % cars[index].route.count
                target = cars[index].route[cars[index].waypoint]
            }
            let vector = target - cars[index].position
            let heading = atan2(vector.x, vector.z)
            let turn = angleDelta(from: cars[index].heading, to: heading)
            cars[index].heading += limited(turn, -dt * 2.4, dt * 2.4)
            var desired = cars[index].cruiseSpeed * (abs(turn) > 0.4 ? 0.3 : 1)
            desired = min(desired, max(4, vector.length * 0.65))
            let onFoot = mode == .walking || mode.isTransitioning
            if onFoot && cars[index].position.distance(to: player) < 16 { desired = 0 }
            let car = cars[index]
            for other in cars where other.id != car.id {
                let relative = other.position - car.position
                let ahead = relative.x * car.forward.x + relative.z * car.forward.z
                let across = abs(relative.x * car.forward.z - relative.z * car.forward.x)
                if ahead > 0 && ahead < 11 && across < 3.1 { desired = 0 }
            }
            for person in pedestrians {
                let relative = person.position - car.position
                let ahead = relative.x * car.forward.x + relative.z * car.forward.z
                let across = abs(relative.x * car.forward.z - relative.z * car.forward.x)
                if ahead > 0 && ahead < 12 && across < 2.5 { desired = 0 }
            }
            cars[index].speed += limited(desired - cars[index].speed, -dt * 19, dt * 4)
            let previous = cars[index].position
            cars[index].position = previous + cars[index].forward * (cars[index].speed * dt)
            let proposed = cars[index].position
            let overlapsCar = cars.contains { $0.id != car.id && $0.position.distance(to: proposed) < 4.3 }
            if world.isBlocked(proposed, radius: 2.2) || overlapsCar {
                cars[index].position = previous
                cars[index].speed = 0
                cars[index].heading = heading
            }
            cars[index].wheelRotation += cars[index].speed * dt / 0.42
        }
    }

    mutating func updatePedestrians(dt: Double) {
        for index in pedestrians.indices {
            guard !pedestrians[index].route.isEmpty else { continue }
            var target = pedestrians[index].route[pedestrians[index].waypoint]
            if target.distance(to: pedestrians[index].position) < 0.8 {
                pedestrians[index].waypoint = (pedestrians[index].waypoint + 1) % pedestrians[index].route.count
                target = pedestrians[index].route[pedestrians[index].waypoint]
            }
            let delta = target - pedestrians[index].position
            pedestrians[index].heading = atan2(delta.x, delta.z)
            var pace = pedestrians[index].pace
            if cars.contains(where: { $0.position.distance(to: pedestrians[index].position) < 5 }) {
                pace = 0
            }
            let previous = pedestrians[index].position
            var proposed = previous + delta.normalized * (pace * dt)
            for car in cars {
                let offset = proposed - car.position
                if offset.length < 2.9 {
                    let away = offset.length > 0.01 ? offset.normalized : Point2(x: cos(car.heading), z: -sin(car.heading))
                    proposed = car.position + away * 2.9
                }
            }
            if !world.isBlocked(proposed, radius: 0.45) { pedestrians[index].position = proposed }
            pedestrians[index].stride += pedestrians[index].position.distance(to: previous) * 3
        }
    }
}

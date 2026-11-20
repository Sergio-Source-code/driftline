import Foundation

struct CityBuilding: Identifiable {
    let id: Int
    let center: Point2
    let width: Double
    let depth: Double
    let height: Double
    let colorIndex: Int
    let isTower: Bool
}

struct CityLayout {
    static let streets: [Double] = [-240, -160, -80, 0, 80, 160, 240]
    var buildings: [CityBuilding] = []
    var palms: [Point2] = []
    var cars: [CarState] = []
    var pedestrians: [Pedestrian] = []

    init() {
        var identifier = 0
        for column in 0..<6 {
            for row in 0..<6 {
                let centerX = Self.streets[column] + 40
                let centerZ = Self.streets[row] + 40
                // Two little plazas break up the downtown grid.
                if (column == 3 && row == 3) || (column == 4 && row == 1) { continue }
                for side in 0..<2 {
                    let hash = (column * 37 + row * 17 + side * 13) % 19
                    let downtown = column >= 2 && column <= 4 && row >= 2 && row <= 4
                    let height = downtown ? Double(24 + hash * 3) : Double(8 + hash)
                    buildings.append(CityBuilding(
                        id: identifier,
                        center: Point2(x: centerX + (side == 0 ? -15 : 15), z: centerZ),
                        width: Double(20 + hash % 5), depth: Double(36 + hash % 12),
                        height: column == 5 ? min(height, 19) : height,
                        colorIndex: hash % 6, isTower: downtown && height > 48
                    ))
                    identifier += 1
                }
            }
        }
        for index in 0..<23 {
            palms.append(Point2(x: 258, z: -230 + Double(index) * 21))
        }
        for index in 0..<15 {
            palms.append(Point2(x: 219, z: -224 + Double(index) * 32))
        }
        cars = [
            CarState(id: 0, kind: .sports, position: Point2(x: 247, z: 31), heading: 0, colorIndex: 0),
            CarState(id: 1, kind: .sedan, position: Point2(x: 247, z: 65), heading: 0, colorIndex: 2),
            CarState(id: 2, kind: .pickup, position: Point2(x: 247, z: -33), heading: 0, colorIndex: 3),
            CarState(id: 3, kind: .sports, position: Point2(x: 7, z: 21), heading: 0, colorIndex: 4),
            CarState(id: 4, kind: .pickup, position: Point2(x: -153, z: 104), heading: 0, colorIndex: 1),
            CarState(id: 5, kind: .sedan, position: Point2(x: 87, z: -118), heading: .pi, colorIndex: 5)
        ]
        for index in 0..<18 {
            let route: [Point2]
            if index >= 12 {
                route = [Point2(x: -268, z: -268), Point2(x: -268, z: 268),
                         Point2(x: 268, z: 268), Point2(x: 268, z: -268)]
            } else {
                let left = Self.streets[index % 4] + 4
                let right = left + 160
                let bottom = Self.streets[(index / 4) % 3] - 4
                let top = bottom + 240
                route = [Point2(x: left, z: bottom), Point2(x: left, z: top),
                         Point2(x: right, z: top), Point2(x: right, z: bottom)]
            }
            let segment = index % 4
            let start = route[segment]
            let end = route[(segment + 1) % 4]
            let fraction = 0.18 + Double(index % 3) * 0.24
            let position = start + (end - start) * fraction
            let heading = atan2(end.x - start.x, end.z - start.z)
            cars.append(CarState(
                id: index + 6, kind: CarKind(rawValue: index % 3) ?? .sedan,
                position: position, heading: heading, colorIndex: (index + 1) % 6,
                route: route, waypoint: (segment + 1) % 4,
                cruiseSpeed: index >= 12 ? 22 : 9 + Double(index % 4), isTraffic: true
            ))
        }
        for index in 0..<48 {
            let route: [Point2]
            if index < 16 {
                let startZ = -218 + Double(index) * 28
                route = [Point2(x: 253, z: startZ), Point2(x: 253, z: min(236, startZ + 48))]
            } else {
                let column = (index - 16) % 6
                let row = ((index - 16) / 6) % 6
                let x = Self.streets[column]
                let z = Self.streets[row]
                route = [Point2(x: x + 12, z: z + 12), Point2(x: x + 12, z: z + 68),
                         Point2(x: x + 68, z: z + 68), Point2(x: x + 68, z: z + 12)]
            }
            pedestrians.append(Pedestrian(
                id: index, position: route[0], heading: 0, route: route,
                waypoint: 1, stride: Double(index), pace: 1.1 + Double(index % 5) * 0.14
            ))
        }
    }

    func makeSimulation() -> GameSimulation {
        var simulation = GameSimulation()
        simulation.player = Point2(x: 253, z: 25)
        simulation.cars = cars
        simulation.pedestrians = pedestrians
        simulation.world.obstacles = buildings.map {
            WorldObstacle(center: $0.center, halfWidth: $0.width / 2, halfDepth: $0.depth / 2)
        }
        return simulation
    }
}

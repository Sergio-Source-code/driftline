import Foundation

struct RGB {
    let r: Double
    let g: Double
    let b: Double

    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 255) / 255
        g = Double((hex >> 8) & 255) / 255
        b = Double(hex & 255) / 255
    }
}

struct WorldFace {
    var vertices: [Vector3]
    var color: RGB
    var shade: Double
    var glow: Bool
    var center: Vector3
    var radius: Double

    init(_ vertices: [Vector3], _ color: RGB, shade: Double = 1, glow: Bool = false) {
        self.vertices = vertices
        self.color = color
        self.shade = shade
        self.glow = glow
        let midpoint = vertices.reduce(.zero, +) * (1 / Double(max(1, vertices.count)))
        center = midpoint
        radius = vertices.map { ($0 - midpoint).length }.max() ?? 0
    }
}

struct MeshBuilder {
    var faces: [WorldFace] = []
    var groundFaces: [WorldFace] = []

    mutating func quad(_ a: Vector3, _ b: Vector3, _ c: Vector3, _ d: Vector3,
                       color: RGB, shade: Double = 1, glow: Bool = false) {
        faces.append(WorldFace([a, b, c, d], color, shade: shade, glow: glow))
    }

    mutating func ground(x: Double, z: Double, width: Double, depth: Double, color: UInt32, y: Double = 0) {
        let x0 = x - width / 2, x1 = x + width / 2
        let z0 = z - depth / 2, z1 = z + depth / 2
        quad(Vector3(x: x0, y: y, z: z0), Vector3(x: x1, y: y, z: z0),
             Vector3(x: x1, y: y, z: z1), Vector3(x: x0, y: y, z: z1), color: RGB(color))
    }

    mutating func box(center: Vector3, width: Double, height: Double, depth: Double,
                      color: UInt32, yaw: Double = 0, glow: Bool = false) {
        let c = cos(yaw), s = sin(yaw)
        let local: [Vector3] = [
            Vector3(x: -width / 2, y: -height / 2, z: -depth / 2),
            Vector3(x: width / 2, y: -height / 2, z: -depth / 2),
            Vector3(x: width / 2, y: -height / 2, z: depth / 2),
            Vector3(x: -width / 2, y: -height / 2, z: depth / 2),
            Vector3(x: -width / 2, y: height / 2, z: -depth / 2),
            Vector3(x: width / 2, y: height / 2, z: -depth / 2),
            Vector3(x: width / 2, y: height / 2, z: depth / 2),
            Vector3(x: -width / 2, y: height / 2, z: depth / 2)
        ]
        let points = local.map { point in
            center + Vector3(x: point.x * c + point.z * s, y: point.y, z: -point.x * s + point.z * c)
        }
        addBoxFaces(points, color: RGB(color), glow: glow)
    }

    mutating func addBoxFaces(_ p: [Vector3], color: RGB, glow: Bool = false) {
        quad(p[0], p[1], p[5], p[4], color: color, shade: 0.77, glow: glow)
        quad(p[1], p[2], p[6], p[5], color: color, shade: 0.9, glow: glow)
        quad(p[2], p[3], p[7], p[6], color: color, shade: 0.86, glow: glow)
        quad(p[3], p[0], p[4], p[7], color: color, shade: 0.67, glow: glow)
        quad(p[4], p[5], p[6], p[7], color: color, shade: 1.08, glow: glow)
    }

    mutating func beam(from: Vector3, to: Vector3, width: Double, color: UInt32) {
        let axis = (to - from).normalized
        let reference = abs(axis.y) > 0.9 ? Vector3(x: 1, y: 0, z: 0) : Vector3(x: 0, y: 1, z: 0)
        let side = axis.cross(reference).normalized * (width / 2)
        let other = axis.cross(side).normalized * (width / 2)
        let p = [from - side - other, from + side - other, from + side + other, from - side + other,
                 to - side - other, to + side - other, to + side + other, to - side + other]
        addBoxFaces(p, color: RGB(color))
    }
}

struct CityArtwork {
    let terrain: [WorldFace]
    let streets: [WorldFace]
    let scenery: [WorldFace]

    init(layout: CityLayout) {
        var base = MeshBuilder()
        base.ground(x: 0, z: 0, width: 566, depth: 566, color: 0x96B8A1)
        base.ground(x: 312, z: 0, width: 58, depth: 2200, color: 0xF5D4A1)
        base.ground(x: 1200, z: 0, width: 1718, depth: 2600, color: 0x43BABC)
        base.ground(x: 345, z: 0, width: 12, depth: 2200, color: 0xA8E2D0, y: 0.015)
        base.ground(x: 339, z: 0, width: 3, depth: 2200, color: 0xEDF0C5, y: 0.025)
        terrain = base.faces

        var road = MeshBuilder()
        for coordinate in CityLayout.streets {
            road.ground(x: coordinate, z: 0, width: 29, depth: 500, color: 0xD5C9B4, y: 0.03)
            road.ground(x: 0, z: coordinate, width: 500, depth: 29, color: 0xD5C9B4, y: 0.03)
        }
        for coordinate in CityLayout.streets {
            road.ground(x: coordinate, z: 0, width: 19, depth: 550, color: 0x52636A, y: 0.06)
            road.ground(x: 0, z: coordinate, width: 550, depth: 19, color: 0x52636A, y: 0.06)
        }
        for side in [-268.0, 268.0] {
            road.ground(x: side, z: 0, width: 23, depth: 560, color: 0x475860, y: 0.07)
            road.ground(x: 0, z: side, width: 560, depth: 23, color: 0x475860, y: 0.07)
        }
        for coordinate in CityLayout.streets + [-268, 268] {
            for dash in stride(from: -276.0, through: 276.0, by: 12.0) {
                let intersection = CityLayout.streets.contains { abs($0 - dash) < 12 }
                if !intersection {
                    road.ground(x: coordinate, z: dash, width: 0.22, depth: 5.2, color: 0xE7D5A0, y: 0.09)
                    road.ground(x: dash, z: coordinate, width: 5.2, depth: 0.22, color: 0xE7D5A0, y: 0.09)
                }
            }
        }
        for x in CityLayout.streets {
            for z in CityLayout.streets {
                for stripe in -2...2 {
                    road.ground(x: x + Double(stripe) * 2.6, z: z + 11.1,
                                width: 1.3, depth: 2.8, color: 0xE8DFCA, y: 0.1)
                }
            }
        }
        streets = road.faces

        var mesh = MeshBuilder()
        let colors: [UInt32] = [0xE8B6A0, 0xE7D5AC, 0x95BEB5, 0xD8C5BD, 0xC9A6AC, 0xA0BDC5]
        for building in layout.buildings {
            let x = building.center.x, z = building.center.z
            mesh.box(center: Vector3(x: x, y: building.height / 2, z: z), width: building.width,
                     height: building.height, depth: building.depth, color: colors[building.colorIndex])
            mesh.box(center: Vector3(x: x, y: building.height + 0.5, z: z), width: building.width + 0.7,
                     height: 1, depth: building.depth + 0.7, color: 0xF5D9B2)
            if building.isTower {
                mesh.box(center: Vector3(x: x, y: building.height + 3.5, z: z), width: building.width * 0.55,
                         height: 6, depth: building.depth * 0.45, color: 0x8FABA9)
            }
            let windowColor: UInt32 = building.colorIndex % 2 == 0 ? 0x548A8F : 0x5F8498
            for floor in stride(from: 4.0, to: building.height - 2, by: 5.5) {
                let halfW = building.width / 2 + 0.035
                let halfD = building.depth / 2 + 0.035
                for side in [-1.0, 1.0] {
                    mesh.quad(Vector3(x: x - halfW + 2, y: floor, z: z + side * halfD),
                              Vector3(x: x + halfW - 2, y: floor, z: z + side * halfD),
                              Vector3(x: x + halfW - 2, y: floor + 1.7, z: z + side * halfD),
                              Vector3(x: x - halfW + 2, y: floor + 1.7, z: z + side * halfD),
                              color: RGB(windowColor), glow: true)
                    mesh.quad(Vector3(x: x + side * halfW, y: floor, z: z - halfD + 2),
                              Vector3(x: x + side * halfW, y: floor, z: z + halfD - 2),
                              Vector3(x: x + side * halfW, y: floor + 1.7, z: z + halfD - 2),
                              Vector3(x: x + side * halfW, y: floor + 1.7, z: z - halfD + 2),
                              color: RGB(windowColor), glow: true)
                }
            }
            if building.height < 25 {
                mesh.box(center: Vector3(x: x, y: 3.5, z: z - building.depth / 2 - 1),
                         width: building.width * 0.8, height: 0.35, depth: 2.8,
                         color: building.id % 2 == 0 ? 0xED895C : 0x499F97)
            }
        }
        for (index, palm) in layout.palms.enumerated() {
            let height = 8.5 + Double(index % 4) * 0.7
            let bottom = Vector3(x: palm.x, y: 0, z: palm.z)
            let top = Vector3(x: palm.x + 1.1, y: height, z: palm.z)
            mesh.beam(from: bottom, to: top, width: 0.48, color: 0xA17C64)
            for leaf in 0..<7 {
                let angle = Double(leaf) * .pi * 2 / 7 + Double(index)
                let direction = Vector3(x: cos(angle), y: 0, z: sin(angle))
                let side = Vector3(x: -sin(angle), y: 0, z: cos(angle))
                let middle = top + direction * 2.4 + Vector3(x: 0, y: 0.5, z: 0)
                let tip = top + direction * 5 + Vector3(x: 0, y: -2.2, z: 0)
                mesh.faces.append(WorldFace([top, middle + side * 0.85, tip, middle - side * 0.85],
                                            RGB(leaf % 2 == 0 ? 0x367B6F : 0x509878)))
            }
        }
        // A waterfront rail, lamps and low-poly beach parasols.
        for z in stride(from: -270.0, through: 270.0, by: 18.0) {
            mesh.box(center: Vector3(x: 281, y: 0.55, z: z), width: 0.25, height: 1.1, depth: 0.25, color: 0xF2D8B7)
            mesh.box(center: Vector3(x: 281, y: 0.9, z: z + 9), width: 0.14, height: 0.12, depth: 18, color: 0xF2D8B7)
        }
        for z in stride(from: -225.0, through: 225.0, by: 40.0) {
            mesh.box(center: Vector3(x: 250.5, y: 3.1, z: z), width: 0.16, height: 6.2, depth: 0.16, color: 0x405D65)
            mesh.box(center: Vector3(x: 249.7, y: 6.3, z: z), width: 1.9, height: 0.22, depth: 0.55, color: 0xFFDE9A, glow: true)
            mesh.box(center: Vector3(x: 309, y: 1.3, z: z), width: 0.12, height: 2.6, depth: 0.12, color: 0xA77C62)
            for section in 0..<8 {
                let a = Double(section) * .pi / 4
                let b = Double(section + 1) * .pi / 4
                mesh.faces.append(WorldFace([
                    Vector3(x: 309, y: 3, z: z),
                    Vector3(x: 309 + cos(a) * 2.7, y: 2.2, z: z + sin(a) * 2.7),
                    Vector3(x: 309 + cos(b) * 2.7, y: 2.2, z: z + sin(b) * 2.7)
                ], RGB(section % 2 == 0 ? 0xF2AD76 : 0xFFF0CD)))
            }
        }
        scenery = mesh.faces
    }
}

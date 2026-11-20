import Foundation

extension MeshBuilder {
    mutating func vehicle(_ car: CarState, door: Double, night: Bool, doorSide: Double = -1,
                          braking: Bool = false) {
        let palette: [UInt32] = [0xFFC64B, 0xF0E1C6, 0x77BFC0, 0xE78364, 0xB2A2CC, 0x80B79C]
        let paint = palette[car.colorIndex % palette.count]
        let length = car.kind.length
        let sports = car.kind == .sports
        let pickup = car.kind == .pickup
        let bodyHeight = sports ? 0.64 : 0.86
        let cabinHeight = sports ? 0.64 : 0.94
        let c = cos(car.heading), s = sin(car.heading)
        func world(_ x: Double, _ y: Double, _ z: Double) -> Vector3 {
            Vector3(x: car.position.x + x * c + z * s, y: y,
                    z: car.position.z - x * s + z * c)
        }
        // Soft, flat contact shadow, chassis and colored bodywork.
        groundFaces.append(WorldFace([
            world(-1.45, 0.13, -length * 0.56), world(1.45, 0.13, -length * 0.56),
            world(1.45, 0.13, length * 0.56), world(-1.45, 0.13, length * 0.56)
        ], RGB(0x354D51)))
        box(center: world(0, 0.53, 0), width: 2.18, height: 0.46, depth: length - 0.2,
            color: 0x263F49, yaw: car.heading)
        box(center: world(0, 0.68 + bodyHeight / 2, 0), width: 2.23,
            height: bodyHeight, depth: length, color: paint, yaw: car.heading)
        let cabinZ = pickup ? 0.35 : -0.2
        let cabinBase = 0.68 + bodyHeight
        let halfCabin = pickup ? 0.85 : 1.25
        let points: [Vector3] = [
            world(-1.0, cabinBase, cabinZ - halfCabin), world(1.0, cabinBase, cabinZ - halfCabin),
            world(1.0, cabinBase, cabinZ + halfCabin), world(-1.0, cabinBase, cabinZ + halfCabin),
            world(-0.84, cabinBase + cabinHeight, cabinZ - halfCabin + 0.3),
            world(0.84, cabinBase + cabinHeight, cabinZ - halfCabin + 0.3),
            world(0.84, cabinBase + cabinHeight, cabinZ + halfCabin - 0.4),
            world(-0.84, cabinBase + cabinHeight, cabinZ + halfCabin - 0.4)
        ]
        for index in 0..<4 {
            let next = (index + 1) % 4
            quad(points[index], points[next], points[next + 4], points[index + 4], color: RGB(0x294F5E))
        }
        quad(points[4], points[5], points[6], points[7], color: RGB(paint), shade: 1.1)
        if pickup {
            box(center: world(0, cabinBase + 0.01, -1.65), width: 1.8, height: 0.05,
                depth: 1.5, color: 0x3B5053, yaw: car.heading)
        }
        if sports {
            box(center: world(0, cabinBase + 0.23, -2.15), width: 2.3, height: 0.12,
                depth: 0.35, color: paint, yaw: car.heading)
        }
        for side in [-1.0, 1.0] {
            for axle in [-1.0, 1.0] {
                let wheelCenter = world(side * 1.11, 0.52, axle * (length * 0.32))
                let turn = car.heading + (axle > 0 ? car.steeringAngle : 0)
                box(center: wheelCenter, width: 0.3, height: 0.86, depth: 0.88,
                    color: 0x22313C, yaw: turn)
                let rim = world(side * 1.28, 0.52, axle * (length * 0.32))
                box(center: rim, width: 0.035, height: 0.44, depth: 0.46, color: 0xCAD9CD, yaw: turn)
            }
            box(center: world(side * 0.74, 0.99, length / 2 + 0.025), width: 0.55,
                height: 0.2, depth: 0.045, color: 0xFFF1C3, yaw: car.heading, glow: true)
            box(center: world(side * 0.8, 0.98, -length / 2 - 0.025), width: 0.5,
                height: braking ? 0.28 : 0.18, depth: 0.045,
                color: braking ? 0xFFB08A : 0xFF7353, yaw: car.heading, glow: true)
        }
        if door > 0.01 {
            let hinge = world(doorSide * 1.1, 1.0, 0.85)
            let doorYaw = car.heading - doorSide * door * 1.05
            let center = hinge + Vector3(x: -sin(doorYaw) * 0.7, y: 0.17, z: -cos(doorYaw) * 0.7)
            box(center: center, width: 0.12, height: 0.8, depth: 1.6, color: paint, yaw: doorYaw)
        }
        if night {
            for side in [-0.7, 0.7] {
                groundFaces.append(WorldFace([
                    world(side - 0.25, 0.14, length / 2), world(side + 0.25, 0.14, length / 2),
                    world(side + 2.5, 0.14, length / 2 + 16), world(side - 2.5, 0.14, length / 2 + 16)
                ], RGB(0x758C78), shade: 0.65, glow: true))
            }
        }
    }

    mutating func person(position: Point2, heading: Double, stride: Double, colorIndex: Int,
                         player: Bool = false, scale: Double = 1) {
        let c = cos(heading), s = sin(heading)
        func world(_ x: Double, _ y: Double, _ z: Double) -> Vector3 {
            Vector3(x: position.x + (x * c + z * s) * scale, y: y * scale,
                    z: position.z + (-x * s + z * c) * scale)
        }
        groundFaces.append(WorldFace([
            world(-0.45, 0.12, -0.3), world(0.45, 0.12, -0.3),
            world(0.45, 0.12, 0.5), world(-0.45, 0.12, 0.5)
        ], RGB(0x435E5B)))
        let shirts: [UInt32] = [0xEC885E, 0x76B9AD, 0xE6CD92, 0xA799CA, 0x77A9C6]
        let skins: [UInt32] = [0xC59170, 0xE2B992, 0x986F57, 0xB88063]
        let skin = skins[colorIndex % skins.count]
        let swing = sin(stride) * 0.32
        let shirt: UInt32 = player ? 0xF6DBC0 : shirts[colorIndex % shirts.count]
        box(center: world(0, 1.25, 0), width: 0.61 * scale, height: 0.67 * scale,
            depth: 0.33 * scale, color: shirt, yaw: heading)
        box(center: world(0, 1.84, 0.02), width: 0.35 * scale, height: 0.4 * scale,
            depth: 0.34 * scale, color: skin, yaw: heading)
        box(center: world(0, 2.03, -0.015), width: 0.36 * scale, height: 0.12 * scale,
            depth: 0.36 * scale, color: 0x35404A, yaw: heading)
        for side in [-1.0, 1.0] {
            let ankle = world(side * 0.16, 0.18, side * swing)
            beam(from: world(side * 0.16, 0.96, 0), to: ankle, width: 0.23 * scale, color: 0x3C6876)
            box(center: ankle, width: 0.25 * scale, height: 0.16 * scale,
                depth: 0.4 * scale, color: 0xF0E1C7, yaw: heading)
            beam(from: world(side * 0.37, 1.47, 0), to: world(side * 0.39, 0.95, -side * swing),
                 width: 0.17 * scale, color: skin)
        }
    }
}

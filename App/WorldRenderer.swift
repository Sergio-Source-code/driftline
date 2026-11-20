import SwiftUI

struct WorldRenderer {
    let artwork: CityArtwork

    func draw(context: GraphicsContext, size: CGSize, game: GameSimulation, camera: ChaseCamera) {
        let daylight = Self.daylight(game.timeOfDay)
        let projection = CameraProjection(camera: camera, width: Double(size.width), height: Double(size.height))
        drawSky(context: context, size: size, game: game, daylight: daylight)
        for face in artwork.terrain { draw(face, context: context, projection: projection, daylight: daylight) }
        // Roads span entire blocks; center-point culling would drop visible ends.
        for face in artwork.streets where visible(face, projection: projection, distance: 360) {
            draw(face, context: context, projection: projection, daylight: daylight)
        }
        var mesh = MeshBuilder()
        for mark in game.tireMarks where mark.end.distance(to: game.focus) < 100 {
            let direction = (mark.end - mark.start).normalized
            let side = Point2(x: direction.z, z: -direction.x) * 0.14
            let a = mark.start - side, b = mark.start + side
            let c = mark.end + side, d = mark.end - side
            let fading = game.elapsed - mark.created > 9
            draw(WorldFace([
                Vector3(x: a.x, y: 0.115, z: a.z), Vector3(x: b.x, y: 0.115, z: b.z),
                Vector3(x: c.x, y: 0.115, z: c.z), Vector3(x: d.x, y: 0.115, z: d.z)
            ], RGB(fading ? 0x46565E : 0x33464F)), context: context, projection: projection, daylight: daylight)
        }
        for car in game.cars where car.position.distance(to: game.focus) < 210 {
            var door = 0.0
            if game.mode.isTransitioning && game.mode.carID == car.id {
                door = sin(game.transitionProgress * .pi)
            }
            mesh.vehicle(car, door: door, night: daylight < 0.45,
                         doorSide: game.mode.carID == car.id ? game.transitionSide : -1,
                         braking: game.mode.carID == car.id && game.braking)
        }
        for person in game.pedestrians where person.position.distance(to: game.focus) < 125 {
            mesh.person(position: person.position, heading: person.heading, stride: person.stride,
                        colorIndex: person.id)
        }
        if game.mode == .walking || game.mode.isTransitioning {
            var scale = 1.0
            if case .entering = game.mode { scale = 1 - max(0, game.transitionProgress - 0.6) * 0.7 }
            if case .exiting = game.mode { scale = 0.72 + min(1, game.transitionProgress / 0.4) * 0.28 }
            mesh.person(position: game.player, heading: game.playerHeading, stride: game.walkStride,
                        colorIndex: 0, player: true, scale: scale)
        }
        // Keep contact shadows and headlights below vehicles and people.
        for face in mesh.groundFaces.sorted(by: { projection.cameraSpace($0.center).z > projection.cameraSpace($1.center).z }) {
            draw(face, context: context, projection: projection, daylight: daylight)
        }
        var rendered: [(face: WorldFace, depth: Double)] = []
        rendered.reserveCapacity(2200)
        for faces in [artwork.scenery, mesh.faces] {
            for face in faces where visible(face, projection: projection, distance: 360) {
                rendered.append((face, projection.cameraSpace(face.center).z))
            }
        }
        rendered.sort { $0.depth > $1.depth }
        for item in rendered { draw(item.face, context: context, projection: projection, daylight: daylight) }
        drawCarMarker(context: context, game: game, projection: projection)
        if game.speed > 33 {
            let amount = min((game.speed - 33) / 20, 1)
            let bounds = CGRect(origin: .zero, size: size)
            context.fill(Path(bounds), with: .radialGradient(
                Gradient(colors: [.clear, Theme.ink.opacity(amount * 0.2)]),
                center: CGPoint(x: size.width / 2, y: size.height / 2),
                startRadius: size.height * 0.45, endRadius: size.width * 0.65
            ))
        }
    }

    static func daylight(_ hour: Double) -> Double {
        limited((sin((hour - 6) / 24 * 2 * .pi) + 0.5) * 1.1, 0.12, 1)
    }

    private func visible(_ face: WorldFace, projection: CameraProjection, distance: Double) -> Bool {
        let offset = face.center - projection.camera.eye
        let radius = face.radius
        if offset.length > distance + radius { return false }
        let depth = offset.dot(projection.forward)
        if depth + radius < 0.4 { return false }
        let horizontal = abs(offset.dot(projection.right))
        let vertical = abs(offset.dot(projection.up))
        let reach = max(0, depth) + radius
        return horizontal <= reach * (projection.width / 2 + 20) / projection.focal + radius &&
            vertical <= reach * (projection.height / 2 + 20) / projection.focal + radius
    }

    private func draw(_ face: WorldFace, context: GraphicsContext, projection: CameraProjection, daylight: Double) {
        let points = projection.polygon(face.vertices)
        guard let first = points.first else { return }
        var path = Path()
        path.move(to: CGPoint(x: first.x, y: first.z))
        for point in points.dropFirst() { path.addLine(to: CGPoint(x: point.x, y: point.z)) }
        path.closeSubpath()
        let depth = max(0, projection.cameraSpace(face.center).z)
        let fog = limited((depth - 85) / 350, 0, 0.7)
        let light = face.glow ? max(0.8, daylight) : 0.24 + daylight * 0.76
        let warmth = daylight * 0.045
        let r = limited(face.color.r * face.shade * light + warmth, 0, 1)
        let g = limited(face.color.g * face.shade * light, 0, 1)
        let b = limited(face.color.b * face.shade * (light + (1 - daylight) * 0.25), 0, 1)
        let fogR = 0.15 + daylight * 0.72
        let fogG = 0.20 + daylight * 0.51
        let fogB = 0.29 + daylight * 0.36
        let color = Color(red: r * (1 - fog) + fogR * fog,
                          green: g * (1 - fog) + fogG * fog,
                          blue: b * (1 - fog) + fogB * fog)
        context.fill(path, with: .color(color))
    }

    private func drawSky(context: GraphicsContext, size: CGSize, game: GameSimulation, daylight: Double) {
        let sunset = max(0, 1 - abs(game.timeOfDay - 18) / 3)
        let top = Color(red: 0.075 + daylight * 0.43 + sunset * 0.17,
                        green: 0.11 + daylight * 0.55 - sunset * 0.13,
                        blue: 0.22 + daylight * 0.51 - sunset * 0.19)
        let horizon = Color(red: 0.16 + daylight * 0.68 + sunset * 0.12,
                            green: 0.21 + daylight * 0.56 - sunset * 0.14,
                            blue: 0.33 + daylight * 0.46 - sunset * 0.22)
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [top, horizon, horizon]), startPoint: .zero,
            endPoint: CGPoint(x: 0, y: size.height * 0.65)
        ))
        let sunCenter = CGPoint(x: size.width * 0.76, y: size.height * (0.16 + sunset * 0.09))
        let sunRadius = size.height * 0.075
        context.fill(Path(ellipseIn: CGRect(x: sunCenter.x - sunRadius * 3, y: sunCenter.y - sunRadius * 3,
                                            width: sunRadius * 6, height: sunRadius * 6)),
                     with: .radialGradient(Gradient(colors: [Theme.gold.opacity(0.3 * daylight), .clear]),
                                           center: sunCenter, startRadius: sunRadius, endRadius: sunRadius * 3))
        context.fill(Path(ellipseIn: CGRect(x: sunCenter.x - sunRadius, y: sunCenter.y - sunRadius,
                                            width: sunRadius * 2, height: sunRadius * 2)),
                     with: .color(daylight > 0.35 ? Color(red: 1, green: 0.89, blue: 0.65) : Theme.cream.opacity(0.8)))
        if daylight < 0.4 {
            for index in 0..<36 {
                let x = Double((index * 137 + 71) % 997) / 997 * size.width
                let y = Double((index * 83 + 43) % 293) / 997 * size.height
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)), with: .color(.white.opacity(0.6)))
            }
        }
        for layer in 0..<2 {
            var ridge = Path()
            ridge.move(to: CGPoint(x: 0, y: size.height * 0.42))
            for index in 0...16 {
                let x = size.width * Double(index) / 16
                let wave = sin(Double(index) * 1.7 + Double(layer)) * 0.018
                let y = size.height * (0.39 + Double(layer) * 0.03 + wave)
                ridge.addLine(to: CGPoint(x: x, y: y))
            }
            ridge.addLine(to: CGPoint(x: size.width, y: size.height * 0.6))
            ridge.addLine(to: CGPoint(x: 0, y: size.height * 0.6))
            ridge.closeSubpath()
            context.fill(ridge, with: .color(Color(red: 0.35 + daylight * 0.23,
                                                  green: 0.39 + daylight * 0.22,
                                                  blue: 0.48 + daylight * 0.19).opacity(0.45)))
        }
    }

    private func drawCarMarker(context: GraphicsContext, game: GameSimulation, projection: CameraProjection) {
        guard game.mode == .walking, let car = game.nearestCar else { return }
        let world = Vector3(x: car.position.x, y: 3.6 + sin(game.elapsed * 2) * 0.14, z: car.position.z)
        let space = projection.cameraSpace(world)
        guard space.z > 1 else { return }
        let point = projection.screenPoint(space)
        let center = CGPoint(x: point.x, y: point.z)
        let rect = CGRect(x: center.x - 14, y: center.y - 14, width: 28, height: 28)
        context.fill(Path(roundedRect: rect, cornerRadius: 9), with: .color(Theme.gold))
        let icon = Text(Image(systemName: "car.fill")).font(.system(size: 12, weight: .bold)).foregroundColor(Theme.ink)
        context.draw(icon, at: center)
    }
}

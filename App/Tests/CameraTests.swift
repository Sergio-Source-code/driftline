import Foundation

@main
struct CameraTests {
    static func main() {
        var game = CityLayout().makeSimulation()
        var camera = ChaseCamera()
        let startFOV = camera.fieldOfView
        precondition(game.interact())
        for _ in 0..<60 { game.step(dt: 1 / 60, joystick: .zero, input: DrivingInput(), cameraHeading: camera.heading) }
        game.cars[0].speed = 48
        for _ in 0..<120 { camera.update(game: game, dt: 1 / 60, shakeEnabled: true) }
        precondition(camera.fieldOfView > startFOV + 10, "Camera must widen with speed")
        camera.update(game: game, dt: 1 / 60, shakeEnabled: false)
        precondition(camera.shake == 0)
        let projection = CameraProjection(camera: camera, width: 844, height: 390)
        let point = projection.screenPoint(projection.cameraSpace(camera.target))
        precondition(abs(point.x - 422) < 0.01 && abs(point.z - 195) < 0.01)
        let behind = camera.eye - projection.forward * 4
        precondition(projection.polygon([behind, behind + projection.right, behind + projection.up]).isEmpty)
        let artwork = CityArtwork(layout: CityLayout())
        precondition(artwork.scenery.count > 1000 && !artwork.streets.isEmpty)
        for face in artwork.scenery {
            let polygon = projection.polygon(face.vertices)
            precondition(polygon.allSatisfy { $0.x.isFinite && $0.z.isFinite })
        }
        print("PASS: speed-responsive camera, shake toggle, perspective, near clipping, procedural city geometry")
    }
}

import SwiftUI

struct CityMap: View {
    let layout: CityLayout
    let simulation: GameSimulation
    var expanded = false

    var body: some View {
        Canvas { context, size in
            drawMap(context: context, size: size)
        }
        .background(Theme.ink)
        .clipShape(RoundedRectangle(cornerRadius: expanded ? 24 : 15))
        .overlay(alignment: .topLeading) {
            if !expanded {
                HStack(spacing: 4) {
                    Image(systemName: "location.north.fill").font(.system(size: 7))
                    Text("N").font(Theme.label(8))
                }
                .foregroundStyle(Theme.cream.opacity(0.8)).padding(9)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: expanded ? 24 : 15)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        }
        .accessibilityLabel("City map. Current district: \(simulation.district)")
    }

    private func drawMap(context: GraphicsContext, size: CGSize) {
        let extent = expanded ? 630.0 : 260.0
        let center = expanded ? Point2.zero : simulation.focus
        let scale = min(size.width, size.height) / extent
        func map(_ point: Point2) -> CGPoint {
            CGPoint(x: size.width / 2 + (point.x - center.x) * scale,
                    y: size.height / 2 - (point.z - center.z) * scale)
        }
        let coast = map(Point2(x: 286, z: 0)).x
        let seaRect = CGRect(x: coast, y: 0, width: max(0, size.width - coast), height: size.height)
        context.fill(Path(seaRect), with: .color(Theme.sea.opacity(0.3)))
        context.fill(Path(CGRect(x: coast - 5, y: 0, width: 5, height: size.height)),
                     with: .color(Theme.gold.opacity(0.2)))
        for building in layout.buildings {
            let point = map(Point2(x: building.center.x - building.width / 2,
                                   z: building.center.z + building.depth / 2))
            let rect = CGRect(x: point.x, y: point.y, width: building.width * scale, height: building.depth * scale)
            context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(Color.white.opacity(0.12)))
        }
        for road in CityLayout.streets {
            var street = Path()
            street.move(to: map(Point2(x: road, z: -268)))
            street.addLine(to: map(Point2(x: road, z: 268)))
            street.move(to: map(Point2(x: -268, z: road)))
            street.addLine(to: map(Point2(x: 268, z: road)))
            context.stroke(street, with: .color(.white.opacity(0.25)), lineWidth: max(2, 9 * scale))
        }
        let loopStart = map(Point2(x: -268, z: 268))
        let loopRect = CGRect(x: loopStart.x, y: loopStart.y, width: 536 * scale, height: 536 * scale)
        context.stroke(Path(roundedRect: loopRect, cornerRadius: 8),
                       with: .color(Theme.gold.opacity(0.55)), lineWidth: max(2, 8 * scale))
        for car in simulation.cars where car.id != simulation.mode.carID {
            let point = map(car.position)
            let radius = expanded ? 2.2 : 2.0
            context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius,
                                                width: radius * 2, height: radius * 2)),
                         with: .color(car.isTraffic ? Theme.cream.opacity(0.4) : Theme.gold.opacity(0.9)))
        }
        let player = map(simulation.focus)
        context.fill(Path(ellipseIn: CGRect(x: player.x - 11, y: player.y - 11, width: 22, height: 22)),
                     with: .color(Theme.gold.opacity(0.16)))
        let heading = simulation.activeCar?.heading ?? simulation.playerHeading
        var arrow = Path()
        let local: [CGPoint] = [CGPoint(x: 0, y: -7), CGPoint(x: 5, y: 5), CGPoint(x: 0, y: 2), CGPoint(x: -5, y: 5)]
        for (index, point) in local.enumerated() {
            let rotated = CGPoint(x: player.x + point.x * cos(heading) - point.y * sin(heading),
                                  y: player.y + point.x * sin(heading) + point.y * cos(heading))
            if index == 0 { arrow.move(to: rotated) } else { arrow.addLine(to: rotated) }
        }
        arrow.closeSubpath()
        context.fill(arrow, with: .color(Theme.gold))
        if expanded {
            let labels: [(String, Point2)] = [
                ("DOWNTOWN", Point2(x: -60, z: 35)),
                ("BEACH", Point2(x: 211, z: 195)),
                ("HIGHWAY LOOP", Point2(x: -35, z: -290))
            ]
            for (label, position) in labels {
                context.draw(Text(label).font(Theme.label(9)).foregroundColor(Theme.cream), at: map(position))
            }
        }
    }
}

struct ExpandedMap: View {
    @Bindable var game: GameController

    var body: some View {
        HStack(spacing: 24) {
            CityMap(layout: game.layout, simulation: game.simulation, expanded: true)
                .aspectRatio(1.16, contentMode: .fit)
            ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("THE COAST IS YOURS").font(Theme.label()).tracking(2).foregroundStyle(Theme.gold)
                Text("Find your\nnext turn.").font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Downtown avenues. A palm-lined beach strip. One long highway loop.")
                    .font(.system(size: 13)).foregroundStyle(Theme.cream.opacity(0.65)).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Circle().fill(Theme.gold).frame(width: 6, height: 6)
                    Text("Parked cars").font(Theme.label())
                    Circle().fill(Theme.cream.opacity(0.5)).frame(width: 6, height: 6)
                    Text("Traffic").font(Theme.label())
                }
                Text("\(game.simulation.visitedDistricts.count)/3 districts explored · \(String(format: "%.1f", game.simulation.distanceDriven / 1000)) km")
                    .font(Theme.label(10)).foregroundStyle(Theme.gold)
                Button {
                    withAnimation(.spring(response: 0.35)) { game.resume() }
                } label: {
                    Label("Back to the coast", systemImage: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.ink).padding(.horizontal, 20).frame(height: 46)
                        .background(Theme.gold, in: Capsule())
                }.buttonStyle(.plain)
            }
            .frame(maxWidth: 250, alignment: .leading)
            }
            .frame(maxWidth: 250)
        }
        .padding(28)
        .foregroundStyle(Theme.cream)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 28))
        .padding(20)
    }
}

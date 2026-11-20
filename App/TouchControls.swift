import SwiftUI

struct DriveJoystick: View {
    @Binding var value: Point2
    let driving: Bool
    let diameter: CGFloat
    @GestureState private var touching = false

    private var radius: CGFloat { diameter * 0.29 }

    var body: some View {
        VStack(spacing: 9) {
            ZStack {
                Circle().fill(Theme.ink.opacity(0.27))
                Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1)
                Circle().strokeBorder(.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [2, 7]))
                    .padding(11)
                Image(systemName: "plus")
                    .font(.system(size: 31, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.35))
                ForEach(0..<4) { index in
                    Capsule().fill(.white.opacity(0.4)).frame(width: 3, height: 7)
                        .offset(y: -diameter / 2 + 7)
                        .rotationEffect(.degrees(Double(index) * 90))
                }
                Circle()
                    .fill(Theme.cream.opacity(touching ? 0.95 : 0.76))
                    .overlay { Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1) }
                    .shadow(color: Theme.ink.opacity(0.3), radius: 10, y: 4)
                    .frame(width: diameter * 0.42, height: diameter * 0.42)
                    .offset(x: value.x * radius, y: -value.z * radius)
            }
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($touching) { _, state, _ in state = true }
                    .onChanged { gesture in
                        let x = Double((gesture.location.x - diameter / 2) / radius)
                        let z = Double(-(gesture.location.y - diameter / 2) / radius)
                        let raw = Point2(x: x, z: z)
                        value = raw.length > 1 ? raw.normalized : raw
                    }
                    .onEnded { _ in release() }
            )
            .onChange(of: touching) { _, active in if !active { release() } }
            .accessibilityLabel(driving ? "Steering joystick" : "Walking joystick")
            .accessibilityHint("Drag in the direction you want to move")
            Text(driving ? "STEER" : "MOVE")
                .font(Theme.label(9)).tracking(3).foregroundStyle(Theme.cream.opacity(0.65))
        }
    }

    private func release() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.68)) { value = .zero }
    }
}

struct PedalButton: View {
    let title: String
    let symbol: String
    let accent: Bool
    let enabled: Bool
    @Binding var pressed: Bool
    @GestureState private var touching = false

    var body: some View {
        VStack(spacing: 11) {
            Image(systemName: symbol).font(.system(size: 23, weight: .semibold))
            Text(title).font(Theme.label(10)).tracking(1.7)
        }
        .foregroundStyle(accent ? Theme.ink : Theme.cream)
        .frame(width: accent ? 76 : 66, height: accent ? 94 : 80)
        .background(background, in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(accent ? 0.4 : 0.18), lineWidth: 1)
        }
        .scaleEffect(pressed ? 0.94 : 1)
        .opacity(enabled ? 1 : 0.32)
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($touching) { _, state, _ in state = true }
                .onChanged { _ in if enabled { pressed = true } }
                .onEnded { _ in pressed = false }
        )
        .onChange(of: touching) { _, value in if !value { pressed = false } }
        .animation(.spring(response: 0.2, dampingFraction: 0.65), value: pressed)
        .accessibilityLabel(title == "GAS" ? "Hold to accelerate" : "Hold to brake, then reverse")
        .accessibilityAddTraits(.isButton)
    }

    private var background: Color {
        if accent { return pressed ? Theme.cream : Theme.gold }
        return pressed ? Theme.coral.opacity(0.8) : Theme.panel
    }
}

struct VehicleControls: View {
    @Bindable var game: GameController

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Button { game.interact() } label: {
                VStack(spacing: 10) {
                    Image(systemName: game.driving ? "figure.walk" : "car.side.fill")
                        .font(.system(size: 22, weight: .medium))
                    Text(game.simulation.interactionTitle)
                        .font(Theme.label(8)).tracking(0.6).lineLimit(1).minimumScaleFactor(0.65)
                }
                .foregroundStyle(game.simulation.canInteract ? Theme.gold : Theme.cream.opacity(0.5))
                .frame(width: 80, height: 80)
                .cockpitPanel(radius: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(game.driving ? "Exit vehicle" : "Enter nearby vehicle")
            PedalButton(title: "BRAKE", symbol: "backward.end.fill", accent: false,
                        enabled: game.driving, pressed: $game.brake)
            PedalButton(title: "GAS", symbol: "chevron.up.2", accent: true,
                        enabled: game.driving, pressed: $game.gas)
        }
    }
}

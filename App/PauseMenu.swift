import SwiftUI

struct PauseMenu: View {
    @Bindable var game: GameController
    @State private var confirmNewCruise = false

    var body: some View {
        GeometryReader { geometry in
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("PULL OVER. BREATHE.").font(Theme.label(10)).tracking(2).foregroundStyle(Theme.gold)
                Text("The city\ncan wait.").font(.system(size: 43, weight: .bold, design: .rounded)).tracking(-1)
                Text("Meridian Coast · \(game.timeLabel)")
                    .font(.system(size: 12)).foregroundStyle(Theme.cream.opacity(0.6))
                Button {
                    withAnimation(.spring(response: 0.35)) { game.resume() }
                } label: {
                    Label("Keep cruising", systemImage: "play.fill")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 24).frame(height: 48)
                        .background(Theme.gold, in: Capsule())
                }.buttonStyle(.plain).padding(.top, 6)
            }
            .frame(width: 220, alignment: .leading)
            Rectangle().fill(.white.opacity(0.12)).frame(width: 1, height: 200)
            ScrollView {
            VStack(alignment: .leading, spacing: 5) {
                Text("SET YOUR MOOD").font(Theme.label(9)).tracking(2)
                    .foregroundStyle(Theme.cream.opacity(0.5)).padding(.bottom, 5)
                Toggle("Original synth radio", isOn: $game.radioEnabled).frame(minHeight: 44)
                Toggle("Sound", isOn: $game.soundEnabled).frame(minHeight: 44)
                Toggle("Camera motion", isOn: $game.shakeEnabled).frame(minHeight: 44)
                Divider().overlay(.white.opacity(0.1)).padding(.vertical, 5)
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        game.paused = false
                        game.showHelp = true
                    }
                } label: {
                    Label("Driving guide", systemImage: "gamecontroller").frame(maxWidth: .infinity, alignment: .leading).frame(height: 44)
                }
                Button { withAnimation(.spring(response: 0.3)) { game.recover() } } label: {
                    Label("Return to the waterfront", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity, alignment: .leading).frame(height: 44)
                }
                .foregroundStyle(Theme.cream.opacity(0.6))
                Button { confirmNewCruise = true } label: {
                    Label("New sunset cruise", systemImage: "sun.horizon.fill")
                        .frame(maxWidth: .infinity, alignment: .leading).frame(height: 44)
                }
                .foregroundStyle(Theme.gold)
            }
            .font(.system(size: 13, weight: .medium))
            .tint(Theme.gold).buttonStyle(.plain)
            }
            .frame(width: 240, height: min(310, geometry.size.height - 80))
        }
        .padding(24)
        .foregroundStyle(Theme.cream).cockpitPanel(radius: 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
        }
        .confirmationDialog("Start a new sunset cruise?", isPresented: $confirmNewCruise, titleVisibility: .visible) {
            Button("Start fresh", role: .destructive) {
                withAnimation(.spring(response: 0.35)) { game.newCruise() }
            }
            Button("Keep this cruise", role: .cancel) { }
        } message: {
            Text("Your current position, cars and exploration progress will be replaced. Sound and camera settings stay the same.")
        }
    }
}

struct DrivingGuide: View {
    @Bindable var game: GameController

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("WELCOME TO MERIDIAN COAST").font(Theme.label(9)).tracking(2).foregroundStyle(Theme.gold)
                    Text("No rush. Just the road.").font(.system(size: 28, weight: .bold, design: .rounded))
                }
                Spacer()
                Button { withAnimation(.spring(response: 0.3)) { game.resume() } } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).frame(width: 44, height: 44)
                }.buttonStyle(.plain).accessibilityLabel("Close guide")
            }
            HStack(alignment: .top, spacing: 25) {
                tip("move.3d", "Find your ride", "Use the left stick to walk. Get near any stopped car, then tap GET IN.")
                tip("steeringwheel", "Make it yours", "Steer with the stick. Hold GAS to go. Hold BRAKE to stop, then reverse.")
                tip("sun.horizon", "Take a detour", "Stop to get out. Tap the map to explore. Tap the radio for an original synth score.")
            }
            Text("Traffic yields to people. The sun sets, the lights come on, and the coast keeps going.")
                .font(.system(size: 11)).foregroundStyle(Theme.cream.opacity(0.5))
        }
        .padding(26).frame(maxWidth: 650).foregroundStyle(Theme.cream).cockpitPanel(radius: 26)
        }
        .frame(maxWidth: 690, maxHeight: 310).padding(20)
    }

    private func tip(_ symbol: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).font(.system(size: 24)).foregroundStyle(Theme.gold).frame(height: 32)
            Text(title).font(.system(size: 15, weight: .bold))
            Text(detail).font(.system(size: 12)).foregroundStyle(Theme.cream.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true).lineSpacing(3)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

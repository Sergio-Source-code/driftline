import SwiftUI

struct GameHUD: View {
    @Bindable var game: GameController

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 390
            let short = geometry.size.height < 340
            VStack(spacing: compact ? 8 : 13) {
                header(compact: geometry.size.width < 680)
                HStack(alignment: .top) {
                    objective(short: short)
                    Spacer(minLength: 18)
                    minimap(compact: compact, short: short)
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 14) {
                    DriveJoystick(value: $game.joystick, driving: game.driving, diameter: compact ? 98 : 116)
                        .padding(.leading, 8)
                    Spacer(minLength: 0)
                    if geometry.size.width > 680 {
                        radio.padding(.bottom, 9)
                    } else {
                        Button {
                            game.radioEnabled.toggle()
                            game.feedback += 1
                            game.saveProgress()
                        } label: {
                            Image(systemName: game.radioEnabled ? "radio.fill" : "speaker.slash.fill")
                                .font(.system(size: 18)).foregroundStyle(Theme.gold)
                                .frame(width: 44, height: 44).cockpitPanel(radius: 14)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(game.radioEnabled ? "Turn radio off" : "Turn radio on")
                        .padding(.bottom, 9)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: compact ? 5 : 9) {
                        speedometer
                        VehicleControls(game: game)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, compact ? 9 : 14)
        }
        .foregroundStyle(Theme.cream)
    }

    private func header(compact: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(Theme.gold)
                    Image(systemName: "road.lanes.curved.left")
                        .font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.ink)
                }.frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("DRIFTLINE")
                        .font(.system(size: 24, weight: .black, design: .rounded)).italic().tracking(2)
                    Text("A LITTLE FURTHER. A LITTLE FREER.")
                        .font(Theme.label(6.5)).tracking(1.5).foregroundStyle(Theme.cream.opacity(0.7))
                }
            }
            Spacer(minLength: 10)
            HStack(spacing: 7) {
                Circle().fill(Theme.gold).frame(width: 5, height: 5)
                if !compact {
                    Text("FREE ROAM").font(Theme.label(9)).tracking(1.8)
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 12).padding(.horizontal, 4)
                }
                Text(game.simulation.district.uppercased()).font(Theme.label(9)).tracking(1)
            }
            .padding(.horizontal, 13).frame(height: 33).cockpitPanel(radius: 11)
            Spacer(minLength: 10)
            HStack(spacing: 8) {
                Image(systemName: WorldRenderer.daylight(game.simulation.timeOfDay) > 0.4 ? "sun.horizon.fill" : "moon.stars.fill")
                    .foregroundStyle(Theme.gold).font(.system(size: 17))
                Text(game.timeLabel).font(Theme.label(12)).monospacedDigit()
            }
            Button { withAnimation(.spring(response: 0.3)) { game.pause() } } label: {
                Image(systemName: "pause.fill").font(.system(size: 13, weight: .bold))
                    .frame(width: 44, height: 44).cockpitPanel(radius: 14)
            }
            .buttonStyle(.plain).accessibilityLabel("Pause game")
        }
        .shadow(color: Theme.ink.opacity(0.16), radius: 5, y: 2)
    }

    private func objective(short: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Capsule().fill(Theme.gold).frame(width: 3, height: 32)
                VStack(alignment: .leading, spacing: 6) {
                    Text(game.missionTitle).font(Theme.label(10)).tracking(1.4)
                    Text(short && game.noticeUntil > game.simulation.elapsed ? game.notice : game.missionDetail)
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.cream.opacity(0.72))
                        .lineLimit(2)
                }
            }
            .padding(12).cockpitPanel(radius: 13)
            if !short && game.noticeUntil > game.simulation.elapsed {
                Label(game.notice, systemImage: "info.circle")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.gold).padding(9).cockpitPanel(radius: 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: 330, alignment: .leading)
        .animation(.spring(response: 0.3), value: game.noticeUntil > game.simulation.elapsed)
    }

    private func minimap(compact: Bool, short: Bool) -> some View {
        Button { withAnimation(.spring(response: 0.35)) { game.openMap() } } label: {
            VStack(spacing: 0) {
                CityMap(layout: game.layout, simulation: game.simulation)
                    .frame(width: compact ? 133 : 151, height: short ? 62 : (compact ? 83 : 101))
                HStack(spacing: 5) {
                    Image(systemName: "location.fill").font(.system(size: 7))
                    Text("MERIDIAN COAST").font(Theme.label(7)).tracking(1)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 7))
                }
                .foregroundStyle(Theme.cream.opacity(0.75))
                .padding(.horizontal, 9).frame(height: 22)
            }
            .cockpitPanel(radius: 15)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open city map")
    }

    private var speedometer: some View {
        HStack(alignment: .bottom, spacing: 9) {
            VStack(alignment: .trailing, spacing: 3) {
                Text(game.simulation.activeCar?.kind.name.uppercased() ?? "ON FOOT")
                    .font(Theme.label(8)).tracking(1.1).foregroundStyle(Theme.cream.opacity(0.7))
                HStack(spacing: 3) {
                    ForEach(0..<12) { index in
                        Capsule().fill(Double(index) / 12 < game.simulation.speed / 51 ? Theme.gold : .white.opacity(0.18))
                            .frame(width: 7, height: 3)
                    }
                }
            }.padding(.bottom, 7)
            Text(String(format: "%03d", game.speedMPH))
                .font(.system(size: 39, weight: .light, design: .rounded)).monospacedDigit().tracking(-1)
            VStack(alignment: .leading, spacing: 1) {
                Text(game.simulation.activeCar.map { $0.speed < -0.2 ? "R" : "D" } ?? "P")
                    .font(Theme.label(11)).foregroundStyle(Theme.gold)
                Text("MPH").font(Theme.label(8)).foregroundStyle(Theme.cream.opacity(0.65))
            }.padding(.bottom, 7)
        }
        .shadow(color: Theme.ink.opacity(0.6), radius: 4, y: 1)
    }

    private var radio: some View {
        Button {
            withAnimation(.spring(response: 0.3)) { game.radioEnabled.toggle() }
            game.feedback += 1
            game.saveProgress()
        } label: {
            HStack(spacing: 9) {
                HStack(alignment: .center, spacing: 2) {
                    ForEach(0..<5) { index in
                        let wave = abs(sin(game.simulation.elapsed * 4 + Double(index) * 1.5))
                        Capsule().fill(Theme.gold.opacity(game.radioEnabled ? 1 : 0.3))
                            .frame(width: 2, height: game.driving && game.radioEnabled && game.soundEnabled ? 5 + wave * 14 : 4)
                    }
                }.frame(width: 20, height: 21)
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.radioEnabled ? "AFTERGLOW FM" : "RADIO OFF")
                        .font(Theme.label(8)).tracking(1)
                    Text(!game.soundEnabled ? "Sound muted" : (game.driving && game.radioEnabled ? "Glass Coast · 108 BPM" : "Your in-car soundtrack"))
                        .font(.system(size: 8)).foregroundStyle(Theme.cream.opacity(0.5))
                }
                Image(systemName: game.radioEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 10)).foregroundStyle(Theme.cream.opacity(0.6))
            }
            .padding(.horizontal, 12).frame(height: 48).cockpitPanel(radius: 14)
        }
        .buttonStyle(.plain).accessibilityLabel(game.radioEnabled ? "Turn radio off" : "Turn radio on")
    }
}

import SwiftUI
import Combine
import AVFoundation

struct ContentView: View {
    @State private var game = GameController()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let clock = Timer.publish(every: 1 / 30, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            Canvas(opaque: true, rendersAsynchronously: false) { context, size in
                game.renderer.draw(context: context, size: size, game: game.simulation, camera: game.camera)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
            cinematicShade
            GameHUD(game: game)
                .opacity(game.paused || game.mapExpanded || game.showHelp ? 0 : 1)
                .allowsHitTesting(!game.paused && !game.mapExpanded && !game.showHelp)
            if game.paused || game.mapExpanded || game.showHelp {
                Theme.ink.opacity(0.5).ignoresSafeArea().transition(.opacity)
                if game.paused { PauseMenu(game: game).transition(.scale(scale: 0.97).combined(with: .opacity)) }
                if game.mapExpanded { ExpandedMap(game: game).transition(.scale(scale: 0.97).combined(with: .opacity)) }
                if game.showHelp { DrivingGuide(game: game).transition(.opacity) }
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .sensoryFeedback(.impact(weight: .light), trigger: game.feedback)
        .onAppear {
            game.start()
            if reduceMotion { game.shakeEnabled = false }
        }
        .onReceive(clock) { date in
            guard scenePhase == .active else { return }
            game.tick(date)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { game.suspend() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
            guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
            game.suspend()
        }
        .onChange(of: reduceMotion) { _, enabled in
            if enabled { game.shakeEnabled = false }
        }
        .onDisappear { game.suspend() }
    }

    private var cinematicShade: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Theme.ink.opacity(0.52), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 115)
            Spacer()
            LinearGradient(colors: [.clear, Theme.ink.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                .frame(height: 140)
        }
        .ignoresSafeArea().allowsHitTesting(false)
    }
}

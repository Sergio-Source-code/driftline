# Driftline

A landscape iPhone free-roam driving prototype built with SwiftUI Canvas and Apple audio frameworks. All city geometry, vehicles, characters, icon artwork and music are generated from original code. No external assets or packages.

## Play

You start on foot beside a yellow **Solstice GT** on Meridian Coast. Move with the left joystick, approach a stopped car, and tap **GET IN**. Hold **GAS** to accelerate, steer with the joystick, and hold **BRAKE** to stop or reverse. Slow below 9 mph to get out. Traffic cars stop for nearby pedestrians and are enterable when stopped.

Explore Downtown, the Beach strip and the Highway loop in a 560 m-wide city with 68 buildings, 24 cars and 48 pedestrians. Other vehicles are the **Vela S4** sedan and **Mesa Trail** pickup. Tap the map for the whole city or the radio to toggle **Afterglow FM**, playing the original synthesized track **Glass Coast**. A full day lasts 12 minutes.

Pause offers sound, radio and camera-motion settings, a driving guide, and recovery to the waterfront. Backgrounding pauses the simulation and sound. Reduced Motion disables camera shake. Audio respects the iPhone silent switch.

## Build

Requires Xcode 15+ and XcodeGen on macOS; deployment target iOS 17. Generate from `project.yml`, then build the App scheme. The pre-build Python script generates the original opaque 1024px sunset/car icon into the asset catalog. Python 3 is available on standard GitHub macOS runners. No generated binary artwork is committed.

`App/Tests` and `App/Tools` are excluded from the application source target. The application has one entry point, `MyApp`.

## Verification

Run `sh App/Tests/run.sh` with a Swift compiler available. Set `SWIFTC` to a compiler path if needed. Tests execute the same Foundation-only model used by the app, not a separate simulation:

- Driving: acceleration, braking, reverse, steering, vehicle speed limits, building collisions.
- Interaction: walking, proximity checks, transition timing, entry into each type, safe-speed exits.
- City: valid spawning, traffic and pedestrian movement over 60 simulated seconds, district detection and clock advancement.
- Camera/art: speed-linked FOV, motion toggle, projection, near-plane clipping and finite procedural geometry.
- Audio: note tuning, non-silent bounded original music and seamless engine waveform.
- Icon: generated PNG dimensions and opaque RGB encoding.

Swift source syntax checks also run. These are **not** a full iOS build or UI tests: SwiftUI/AVFoundation type-checking, on-device performance, multi-touch, audio routing and final visual layout require the macOS build runner and an iPhone/simulator.

## Scope

This is a small stylized sandbox, not a commercial-scale open-world engine. It uses CPU-projected low-poly geometry in SwiftUI Canvas, arcade collisions, fixed traffic routes and a session-only world. No combat, missions, licensed assets, networking or saved game is included.

#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
SWIFTC="${SWIFTC:-swiftc}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
CORE="App/DrivingModel.swift App/GameSimulation.swift App/CityLayout.swift App/CameraMath.swift App/CityArtwork.swift App/VehicleArtwork.swift App/Synthesizer.swift"
for suite in Driving Interaction City Camera Sound Integration; do
    "$SWIFTC" $CORE "App/Tests/${suite}Tests.swift" -o "$WORK/$suite"
    "$WORK/$suite"
done
"$SWIFTC" -frontend -parse App/*.swift
python3 App/Tools/render_icon.py "$WORK/Icon"
python3 - "$WORK/Icon/DriftlineIcon.png" <<'PY'
import struct, sys
with open(sys.argv[1], 'rb') as image:
    header = image.read(26)
assert header[:8] == b'\x89PNG\r\n\x1a\n'
assert struct.unpack('>II', header[16:24]) == (1024, 1024)
assert header[25] == 2, 'App icon must be opaque RGB'
print('PASS: original icon dimensions and opaque PNG format')
PY

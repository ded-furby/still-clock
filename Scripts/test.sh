#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcrun swiftc -swift-version 5 -O -parse-as-library Sources/ClockCore/*.swift Scripts/Checks.swift \
  -framework AppKit -framework SwiftUI -framework ScreenSaver -o build/checks
build/checks
if [ -d "build/Still Clock.saver" ]; then
  xcrun swiftc -swift-version 5 -parse-as-library Scripts/SmokeTest.swift -framework AppKit -framework ScreenSaver -o build/saver-smoke
  build/saver-smoke "$PWD/build/Still Clock.saver"
fi

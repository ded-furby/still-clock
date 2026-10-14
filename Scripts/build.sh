#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${VERSION:-1.0.0}"
OUT="${BUILD_DIR:-$PWD/build}"
APP="$OUT/Still Clock.app"
SAVER="$OUT/Still Clock.saver"
ARCHS="${ARCHS:-$(uname -m)}"
SDK="$(xcrun --show-sdk-path)"
mkdir -p "$OUT" "$APP/Contents/MacOS" "$APP/Contents/Resources" "$SAVER/Contents/MacOS" "$SAVER/Contents/Resources"
for arch in $ARCHS; do
  echo "Building Still Clock for ${arch}…"
  xcrun swiftc -swift-version 5 -O -whole-module-optimization -sdk "$SDK" -target "$arch-apple-macosx13.0" \
    -D DIRECT_BUILD -module-name StillClock Sources/ClockCore/*.swift Sources/StillClock/*.swift \
    -framework AppKit -framework SwiftUI -framework ScreenSaver -framework ServiceManagement \
    -o "$OUT/StillClock-$arch"
  xcrun swiftc -swift-version 5 -O -whole-module-optimization -sdk "$SDK" -target "$arch-apple-macosx13.0" \
    -emit-library -module-name StillSaver Sources/ClockCore/*.swift Sources/StillSaver/*.swift \
    -framework AppKit -framework SwiftUI -framework ScreenSaver -o "$OUT/StillSaver-$arch"
done
APP_INPUTS=(); SAVER_INPUTS=()
for arch in $ARCHS; do APP_INPUTS+=("$OUT/StillClock-$arch"); SAVER_INPUTS+=("$OUT/StillSaver-$arch"); done
lipo -create "${APP_INPUTS[@]}" -output "$APP/Contents/MacOS/StillClock"
lipo -create "${SAVER_INPUTS[@]}" -output "$SAVER/Contents/MacOS/StillSaver"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.dedfurby.StillClock</string>
<key>CFBundleName</key><string>Still Clock</string>
<key>CFBundleDisplayName</key><string>Still Clock</string>
<key>CFBundleExecutable</key><string>StillClock</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSUIElement</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
cat > "$SAVER/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.dedfurby.StillClock.saver</string>
<key>CFBundleName</key><string>Still Clock</string>
<key>CFBundleExecutable</key><string>StillSaver</string>
<key>CFBundlePackageType</key><string>BNDL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSPrincipalClass</key><string>StillSaverView</string>
</dict></plist>
PLIST
if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/"; fi
if [ -f Resources/thumbnail.png ]; then
  cp Resources/thumbnail.png "$SAVER/Contents/Resources/thumbnail.png"
  cp Resources/thumbnail.png "$SAVER/Contents/Resources/thumbnail@2x.png"
fi
codesign --force --sign "${SIGNING_IDENTITY:--}" --timestamp=none "$SAVER"
rm -rf "$APP/Contents/Resources/Still Clock.saver"
ditto "$SAVER" "$APP/Contents/Resources/Still Clock.saver"
codesign --force --sign "${SIGNING_IDENTITY:--}" --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"
codesign --verify --strict "$SAVER"
echo "Built: $APP"
echo "Built: $SAVER"

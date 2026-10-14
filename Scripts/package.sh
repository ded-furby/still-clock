#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${VERSION:-1.0.1}"
NAME="StillClock-${VERSION}-universal"
test -d "build/Still Clock.app"
test -d "build/Still Clock.saver"
for binary in "build/Still Clock.app/Contents/MacOS/StillClock" "build/Still Clock.saver/Contents/MacOS/StillSaver"; do
  architectures="$(lipo -archs "$binary")"
  for architecture in arm64 x86_64; do
    case " $architectures " in
      *" $architecture "*) ;;
      *) echo "Missing $architecture in $binary" >&2; exit 1 ;;
    esac
  done
done
mkdir -p dist build/package
STAGING="$(mktemp -d "$PWD/build/package/still.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
ditto "build/Still Clock.app" "$STAGING/Still Clock.app"
ditto "build/Still Clock.saver" "$STAGING/Still Clock.saver"
cp docs/SETUP.md "$STAGING/READ ME.md"
cp LICENSE "$STAGING/LICENSE.txt"
ln -s /Applications "$STAGING/Applications"
ditto -c -k --sequesterRsrc --keepParent "$STAGING/Still Clock.app" "dist/${NAME}.zip"
hdiutil create -volname "Still Clock" -srcfolder "$STAGING" -ov -format UDZO "dist/${NAME}.dmg"
(cd dist && shasum -a 256 "${NAME}.dmg" "${NAME}.zip" > SHA256SUMS.txt)
echo "Packaged in $PWD/dist"

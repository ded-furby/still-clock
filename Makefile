.PHONY: build test universal package artwork
build:
	./Scripts/build.sh
test:
	./Scripts/test.sh
universal:
	ARCHS="arm64 x86_64" ./Scripts/build.sh
package: universal test
	./Scripts/package.sh
artwork:
	mkdir -p build
	xcrun swiftc -swift-version 5 -O -parse-as-library Sources/ClockCore/*.swift Scripts/Artwork.swift -framework AppKit -framework SwiftUI -framework ScreenSaver -o build/artwork
	build/artwork
	iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns

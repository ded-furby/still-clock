// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StillClock",
    platforms: [.macOS(.v13)],
    products: [.library(name: "ClockCore", targets: ["ClockCore"]),
               .executable(name: "StillClock", targets: ["StillClock"])],
    targets: [.target(name: "ClockCore", linkerSettings: [.linkedFramework("ScreenSaver")]),
              .executableTarget(name: "StillClock", dependencies: ["ClockCore"]),
              .testTarget(name: "ClockCoreTests", dependencies: ["ClockCore"])]
)

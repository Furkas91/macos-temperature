// swift-tools-version: 6.0
import PackageDescription

// Prefer `./scripts/package.sh` when using Command Line Tools only.
// Full Xcode: `swift build -c release` should work.
let package = Package(
    name: "TemperatureBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TemperatureBar", targets: ["TemperatureBar"])
    ],
    targets: [
        .executableTarget(
            name: "TemperatureBar",
            path: "Sources/TemperatureBar",
            exclude: ["Info.plist"],
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        )
    ]
)

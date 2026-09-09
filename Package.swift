// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "InputReplay",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "InputReplayCore", targets: ["InputReplayCore"]),
        .executable(name: "InputReplayProbe", targets: ["InputReplayProbe"])
    ],
    targets: [
        .target(
            name: "InputReplayCore",
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon")
            ]
        ),
        .executableTarget(
            name: "InputReplayProbe",
            dependencies: ["InputReplayCore"]
        ),
        .testTarget(
            name: "InputReplayCoreTests",
            dependencies: ["InputReplayCore"]
        )
    ]
)

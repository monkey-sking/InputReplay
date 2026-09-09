// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "InputReplay",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "InputReplayCore", targets: ["InputReplayCore"]),
        .executable(name: "InputReplayProbe", targets: ["InputReplayProbe"]),
        .executable(name: "InputReplayApp", targets: ["InputReplayApp"])
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
        .executableTarget(
            name: "InputReplayApp",
            dependencies: ["InputReplayCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "InputReplayCoreTests",
            dependencies: ["InputReplayCore"]
        )
    ]
)

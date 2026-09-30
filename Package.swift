// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ListeningModeMenu",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "ListeningModeMenu", targets: ["ListeningModeMenu"]),
    ],
    targets: [
        .executableTarget(name: "ListeningModeMenu"),
        .testTarget(
            name: "ListeningModeMenuTests",
            dependencies: ["ListeningModeMenu"]
        ),
    ]
)

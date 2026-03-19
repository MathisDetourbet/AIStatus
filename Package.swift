// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AIStatus",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "AIStatusKit", targets: ["AIStatusKit"]),
        .executable(name: "AIStatusBar", targets: ["AIStatusBar"]),
        .executable(name: "aistatus", targets: ["aistatus"]),
    ],
    targets: [
        .target(
            name: "AIStatusKit"
        ),
        .executableTarget(
            name: "AIStatusBar",
            dependencies: ["AIStatusKit"],
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "aistatus",
            dependencies: ["AIStatusKit"]
        ),
        .testTarget(
            name: "AIStatusKitTests",
            dependencies: ["AIStatusKit"]
        ),
    ]
)

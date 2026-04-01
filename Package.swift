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
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-nonempty", from: "0.5.0"),
    ],
    targets: [
        .target(
            name: "AIStatusKit",
            dependencies: [
                .product(name: "NonEmpty", package: "swift-nonempty"),
            ]
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

// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "IPC",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(
            name: "IPC",
            targets: ["IPC"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/vmanot/Swallow.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "IPC",
            dependencies: [
                "Swallow"
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "IPCTests",
            dependencies: ["IPC"],
            path: "Tests"
        )
    ]
)

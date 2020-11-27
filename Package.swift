// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "IPC",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "IPC",
            targets: ["IPC"]
        )
    ],
    targets: [
        .target(
            name: "IPC",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "IPCTests",
            dependencies: ["IPC"],
            path: "Tests"
        )
    ]
)

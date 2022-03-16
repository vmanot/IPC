// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "IPC",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
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

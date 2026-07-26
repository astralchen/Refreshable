// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Refreshable",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "Refreshable", targets: ["Refreshable"]),
        .library(name: "RefreshableStyles", targets: ["RefreshableStyles"]),
    ],
    targets: [
        .target(name: "Refreshable"),
        .target(name: "RefreshableStyles", dependencies: ["Refreshable"]),
        .testTarget(name: "RefreshableTests", dependencies: ["Refreshable"]),
        .testTarget(
            name: "RefreshableStylesTests",
            dependencies: ["RefreshableStyles", "Refreshable"]
        ),
    ]
)

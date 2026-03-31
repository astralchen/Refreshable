// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Refreshable",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "Refreshable", targets: ["Refreshable"]),
    ],
    targets: [
        .target(name: "Refreshable"),
        .testTarget(name: "RefreshableTests", dependencies: ["Refreshable"]),
    ]
)

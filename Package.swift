// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Simplicity",
    platforms: [
        .iOS(.v16),
        .macCatalyst(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Simplicity",
            targets: ["Simplicity"]
        ),
    ],
    targets: [
        .target(
            name: "Simplicity"
        ),
        .testTarget(
            name: "SimplicityTests",
            dependencies: ["Simplicity"]
        ),
    ]
)

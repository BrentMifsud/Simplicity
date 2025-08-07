// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Simplicity",
    platforms: [
        .iOS(.v13),
        .macCatalyst(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .macOS(.v10_15)
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

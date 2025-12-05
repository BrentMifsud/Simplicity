// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Simplicity",
    platforms: [
        .iOS(.v17),
        .macCatalyst(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "Simplicity",
            targets: ["Simplicity"]
        ),
    ],
    targets: [
        .target(
            name: "Simplicity",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .strictMemorySafety(),
                .defaultIsolation(nil),
                .enableUpcomingFeature("InferIsolatedConformances"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "SimplicityTests",
            dependencies: ["Simplicity"]
        ),
    ]
)

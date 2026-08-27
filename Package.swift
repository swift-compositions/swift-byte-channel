// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-byte-channel",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(name: "Byte Chunk", targets: ["Byte Chunk"]),
        .library(name: "Byte Channel", targets: ["Byte Channel"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-molecules/swift-async.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-buffer-linear.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-buffer.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-byte.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-index.git",
            branch: "main"
        ),
    ],
    targets: [
        .target(
            name: "Byte Chunk",
            dependencies: [
                .product(
                    name: "Buffer Linear",
                    package: "swift-buffer-linear"
                ),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Index", package: "swift-index"),
            ]
        ),
        .target(
            name: "Byte Channel",
            dependencies: [
                "Byte Chunk",
                .product(name: "Async Channel", package: "swift-async"),
                .product(name: "Async Semaphore", package: "swift-async"),
                .product(name: "Buffer Protocol", package: "swift-buffer"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Index", package: "swift-index"),
            ]
        ),
        .testTarget(
            name: "Byte Channel Tests",
            dependencies: ["Byte Channel"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings =
        (target.swiftSettings ?? []) + [
            .strictMemorySafety(),
            .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("InternalImportsByDefault"),
            .enableUpcomingFeature("MemberImportVisibility"),
            .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            .enableExperimentalFeature("LifetimeDependence"),
            .enableExperimentalFeature("Lifetimes"),
        ]
}

// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "Candlebar",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "Candlebar", targets: ["Candlebar"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.3"),
    ],
    targets: [
        .executableTarget(
            name: "Candlebar",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/Candlebar",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .testTarget(
            name: "CandlebarTests",
            dependencies: ["Candlebar"],
            path: "Tests/CandlebarTests",
        ),
    ],
)

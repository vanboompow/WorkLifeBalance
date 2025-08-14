// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WorkLifeBalance",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "WorkLifeBalance",
            targets: ["WorkLifeBalance"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0"),
    ],
    targets: [
        .executableTarget(
            name: "WorkLifeBalance",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
            ],
            path: "WorkLifeBalance",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("ForwardTrailingClosures"),
                .enableUpcomingFeature("ImplicitOpenExistentials"),
                .enableUpcomingFeature("StrictConcurrency"),
                .enableUpcomingFeature("DisableOutwardActorInference")
            ]
        ),
        .testTarget(
            name: "WorkLifeBalanceTests",
            dependencies: ["WorkLifeBalance"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
    ]
)

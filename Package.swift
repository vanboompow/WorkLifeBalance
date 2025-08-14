// swift-tools-version: 5.9
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
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.14.0"),
    ],
    targets: [
        .executableTarget(
            name: "WorkLifeBalance",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
            ],
            path: "WorkLifeBalance"
        ),
        .testTarget(
            name: "WorkLifeBalanceTests",
            dependencies: ["WorkLifeBalance"]
        ),
    ]
)

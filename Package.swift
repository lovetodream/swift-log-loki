// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-log-loki",
    products: [
        .library(
            name: "LoggingLoki",
            targets: ["LoggingLoki"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "LoggingLoki",
            dependencies: [
                .product(name: "Logging", package: "swift-log")]),
        .testTarget(
            name: "LoggingLokiTests",
            dependencies: ["LoggingLoki"]),
    ]
)

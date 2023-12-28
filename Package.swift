// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "swift-log-loki",
    platforms: [.macOS(.v11), .iOS(.v14), .tvOS(.v14), .watchOS(.v7)],
    products: [
        .library(name: "LoggingLoki", targets: ["LoggingLoki"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.6.0"),
        .package(url: "https://github.com/lovetodream/swift-snappy", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "LoggingLoki",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "Snappy", package: "swift-snappy"),
            ]
        ),
        .testTarget(name: "LoggingLokiTests", dependencies: ["LoggingLoki"]),
    ]
)

// swift-tools-version: 6.2
import PackageDescription

let availability =
    "AvailabilityMacro=logLoki 1.0:macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0"

let package = Package(
    name: "swift-log-loki",
    products: [
        .library(name: "LoggingLoki", targets: ["LoggingLoki"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.102.0"),
        .package(url: "https://github.com/lovetodream/swift-snappy.git", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "LoggingLoki",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "NIOFoundationEssentialsCompat", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "Snappy", package: "swift-snappy"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
            ],
            swiftSettings: [
                .strictMemorySafety(),
                .treatAllWarnings(as: .error),
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature(availability),

                // https://github.com/apple/swift-evolution/blob/main/proposals/0335-existential-any.md
                .enableUpcomingFeature("ExistentialAny"),
                // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0444-member-import-visibility.md
                .enableUpcomingFeature("MemberImportVisibility"),
                // https://forums.swift.org/t/experimental-support-for-lifetime-dependencies-in-swift-6-2-and-beyond/78638
                .enableExperimentalFeature("Lifetimes"),
                // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        ),
        .testTarget(
            name: "LoggingLokiTests",
            dependencies: ["LoggingLoki"],
            swiftSettings: [.enableExperimentalFeature(availability)]
        ),
    ]
)

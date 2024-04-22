# SwiftLogLoki

[![Coverage](https://codecov.io/gh/lovetodream/swift-log-loki/graph/badge.svg?token=Q70PZWS0T2)][Coverage]
[![Documentation](http://img.shields.io/badge/read_the-docs-2196f3.svg)][Documentation]
[![Apache 2.0 License](https://img.shields.io/badge/license-Apache%202.0-brightgreen)][Apache License]
[![CI](https://github.com/lovetodream/swift-log-loki/actions/workflows/ci.yml/badge.svg)](https://github.com/lovetodream/swift-log-loki/actions/workflows/ci.yml)
[![Swift Versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Flovetodream%2Fswift-log-loki%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/lovetodream/swift-log-loki)
[![Supported Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Flovetodream%2Fswift-log-loki%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/lovetodream/swift-log-loki)

This library can be used as an implementation of Apple's [swift-log](https://github.com/apple/swift-log) interface that captures console logs from apps or services and sends them to [Grafana Loki](https://grafana.com/oss/loki).

## Features

- Supports Linux and all Apple platforms
- Different logging levels such as `trace`, `debug`, `info`, `notice`, `warning`, `error` and `critical`
- Option to send logs as snappy-compressed Protobuf (default) or JSON
- Send logs in batches via `Duration` since batch creation, amount of log entries in batch or a mix of both options

## Add dependency

### Swift Package

Add `LoggingLoki` to the dependencies within your application's `Package.swift` file.

```swift
.package(url: "https://github.com/lovetodream/swift-log-loki.git", from: "2.0.0"),
```

Add `LoggingLoki` to your target's dependencies.

```swift
.product(name: "LoggingLoki", package: "swift-log-loki"),
``` 

### Xcode Project

Go to `File` > `Add Packages`, enter the Package URL `https://github.com/lovetodream/swift-log-loki.git` and press `Add Package`.


## Usage

You can use LoggingLoki as your default Log Handler for [swift-log](https://github.com/apple/swift-log).

```swift
import Logging
import LoggingLoki

let processor = LokiLogProcessor(
    configuration: LokiLogProcessorConfiguration(lokiURL: "http://localhost:3100")
)
LoggingSystem.bootstrap { label in
    LokiLogHandler(label: label, processor: processor)
}

try await withThrowingDiscardingTaskGroup { group in
    group.addTask {
        // The processor has to run in the background to send logs to Loki.
        try await processor.run()
    }
}
```

## API documentation

For more information visit the [API reference][Documentation].

## License

[Apache 2.0][Apache License]

Copyright (c) 2022-present, Timo Zacherl (@lovetodream)

_This project contains code written by others not affliated with this project. All copyright claims are reserved by them. For a full list, with their claimed rights, see [NOTICE.txt](NOTICE.txt)_

_**Swift** is a registered trademark of **Apple, Inc**. Any use of their trademark does not imply any affiliation with or endorsement by them, and all rights are reserved by them._

[Coverage]: https://codecov.io/gh/lovetodream/swift-log-loki
[Documentation]: https://swiftpackageindex.com/lovetodream/swift-log-loki/documentation/loggingloki
[Apache License]: LICENSE

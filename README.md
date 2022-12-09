# SwiftLogLoki

[![Tests](https://github.com/lovetodream/swift-log-loki/actions/workflows/tests.yml/badge.svg)](https://github.com/lovetodream/swift-log-loki/actions/workflows/tests.yml)
[![Docs](https://github.com/lovetodream/swift-log-loki/actions/workflows/deploy_docs.yml/badge.svg)](https://github.com/lovetodream/swift-log-loki/actions/workflows/deploy_docs.yml)

This library can be used as an implementation of Apple's [swift-log](https://github.com/apple/swift-log) interface that captures console logs from apps or services and sends them to [Grafana Loki](https://grafana.com/oss/loki).

## Features

- Supports Darwin (macOS), Linux platforms, iOS, watchOS and tvOS
- Different logging levels such as `trace`, `debug`, `info`, `notice`, `warning`, `error` and `critical`
- Option to send logs as snappy-compressed Protobuf (default) or JSON
- Batching logs via `TimeInterval`, amount of log entries or a mix of those options

## Add dependency

### Swift Package

Add `LoggingLoki` to the dependencies within your application's `Package.swift` file.

```swift
.package(url: "https://github.com/lovetodream/swift-log-loki.git", from: "1.0.0"),
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
import LoggingLoki
import Logging

// yourLokiURL: e.g. http://localhost:3100 as URL
LoggingSystem.bootstrap { LokiLogHandler(label: $0, lokiURL: yourLokiURL) }
```

### Example Usage with [Swift Vapor](https://vapor.codes)

LoggingLoki works great with [Swift Vapor](https://vapor.codes), to send all your logs to [Grafana Loki](https://grafana.com/oss/loki) add the following to the top of your `configure(_:)` method inside of `configure.swift`.

```swift
app.logger = Logger(label: app.logger.label, factory: { label in
    // yourLokiURL: e.g. http://localhost:3100 as URL
    LokiLogHandler(label: label, lokiURL: yourLokiURL)
})
```

For more information about Logging in [Swift Vapor](https://vapor.codes) take a look at the [Official Documentation](https://docs.vapor.codes/basics/logging/). 

## API documentation

For more information visit the [API reference](https://timozacherl.com/swift-log-loki/documentation/loggingloki/).

## License

This library is licensed under the MIT license. Full license text is available in [LICENSE](https://github.com/lovetodream/swift-log-loki/blob/main/LICENSE).

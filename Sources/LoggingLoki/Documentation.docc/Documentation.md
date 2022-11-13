# ``LoggingLoki``

This library can be used as an implementation of Apple's swift-log interface that captures console logs from apps or services and sends them to Grafana Loki.

## Overview

LoggingLoki provides a logging backend for [swift-log](https://github.com/apple/swift-log) with support for sending logs to a [Grafana Loki](https://grafana.com/oss/loki) instance. It includes the following list of features.

- Supports Darwin (macOS), Linux platforms, iOS, watchOS and tvOS
- Different logging levels such as `trace`, `debug`, `info`, `notice`, `warning`, `error` and `critical`

## Topics

### Essentials

- ``LokiLogHandler``

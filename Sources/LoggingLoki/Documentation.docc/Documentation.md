# ``LoggingLoki``

This library can be used as an implementation of Apple's swift-log interface that captures console logs from apps or services and sends them to Grafana Loki.

## Usage

You'll have to configure your Logger with a ``LokiLogHandler``.

The handler needs a ``LokiLogProcessor`` to send logs to your Loki server.
> Note: Logs can be sent to Loki as long as ``LokiLogProcessor/run()`` is not cancelled.

@Snippet(path: "swift-log-loki/Snippets/BasicUsage", slice: "setup")

## Topics

### Essentials

- ``LokiLogHandler``
- ``LokiLogProcessor``

### Configuration

- ``LokiLogProcessorConfiguration``

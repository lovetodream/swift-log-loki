
// snippet.setup
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
// snippet.end

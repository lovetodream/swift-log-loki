import XCTest
@testable import LoggingLoki

final class LokiLogProcessorTests: XCTestCase {
    func testLogFmtFormat() {
        let configuration = LokiLogProcessorConfiguration(
            lokiURL: "http://localhost:3100",
            metadataFormat: .logfmt
        )
        let processor = LokiLogProcessor(configuration: configuration)
        let raw = LokiLog(
            timestamp: .init(),
            level: .info,
            message: "My log message",
            metadata: ["basic_key": "basic_value", "additional_key": "value with whitespace"]
        )
        let formatted = processor.makeLog(raw)
        XCTAssertNil(formatted.metadata)
        XCTAssertTrue(formatted.line.starts(with: "[INFO] "))
        XCTAssertTrue(formatted.line.contains("basic_key=basic_value"))
        XCTAssertTrue(formatted.line.contains(#"additional_key="value with whitespace""#))
        XCTAssertTrue(formatted.line.contains(#"message="My log message""#))
    }

    func testCustomFormat() {
        let configuration = LokiLogProcessorConfiguration(
            lokiURL: "http://localhost:3100",
            metadataFormat: .custom({ level, message, metadata in
                "\(level.rawValue.uppercased()): \(message) \(metadata)"
            })
        )
        let processor = LokiLogProcessor(configuration: configuration)
        let raw = LokiLog(
            timestamp: .init(),
            level: .info,
            message: "My log message",
            metadata: ["basic_key": "basic_value", "additional_key": "value with whitespace"]
        )
        let formatted = processor.makeLog(raw)
        XCTAssertNil(formatted.metadata)
        XCTAssertEqual(formatted.line, #"INFO: My log message ["basic_key": basic_value, "additional_key": value with whitespace]"#)
    }
}

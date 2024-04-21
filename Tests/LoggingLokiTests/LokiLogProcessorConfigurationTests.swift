import XCTest
@testable import LoggingLoki

final class LokiLogProcessorConfigurationTests: XCTestCase {
    func testLokiURLConstruction() {
        var configuration1 = LokiLogProcessorConfiguration(lokiURL: "http://localhost:3100")
        XCTAssertEqual(configuration1._lokiURL, "http://localhost:3100/loki/api/v1/push")
        configuration1.lokiURL = "http://localhost:3200/"
        XCTAssertEqual(configuration1._lokiURL, "http://localhost:3200/loki/api/v1/push")
        configuration1.lokiURL = "http://localhost:3300"
        XCTAssertEqual(configuration1._lokiURL, "http://localhost:3300/loki/api/v1/push")
        var configuration2 = LokiLogProcessorConfiguration(lokiURL: "http://localhost:3100/")
        XCTAssertEqual(configuration2._lokiURL, "http://localhost:3100/loki/api/v1/push")
    }
}
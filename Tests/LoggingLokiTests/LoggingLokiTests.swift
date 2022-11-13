import XCTest
@testable import SwiftLogLoki

final class LoggingLokiTests: XCTestCase {
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(SwiftLogLoki().text, "Hello, World!")
    }
}

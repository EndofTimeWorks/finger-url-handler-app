import XCTest
@testable import Finger

final class FingerTargetTests: XCTestCase {
    func testParsesStandardRequest() throws {
        let target = try FingerTarget(url: try XCTUnwrap(URL(string: "finger://example.com/alice")))

        XCTAssertEqual(target, FingerTarget(host: "example.com", request: "alice"))
    }

    func testParsesUserHostConvenienceForm() throws {
        let target = try FingerTarget(url: try XCTUnwrap(URL(string: "finger://alice@example.com")))

        XCTAssertEqual(target, FingerTarget(host: "example.com", request: "alice"))
    }

    func testParsesIPv6PortAndVerboseRequest() throws {
        let target = try FingerTarget(url: try XCTUnwrap(URL(string: "finger://[2001:db8::1]:7979/%2FW%20alice")))

        XCTAssertEqual(target, FingerTarget(host: "2001:db8::1", port: 7979, request: "alice", verbose: true))
    }

    func testRejectsEncodedLineBreak() throws {
        XCTAssertThrowsError(try FingerTarget(url: try XCTUnwrap(URL(string: "finger://example.com/alice%0D%0Aroot")))) { error in
            XCTAssertEqual(error as? FingerTargetError, .invalidRequest)
        }
    }

    func testRejectsDoubleEncodedLineBreak() throws {
        XCTAssertThrowsError(try FingerTarget(url: try XCTUnwrap(URL(string: "finger://example.com/alice%250D%250Aroot")))) { error in
            XCTAssertEqual(error as? FingerTargetError, .invalidRequest)
        }
    }

    func testCanonicalURLPreservesIPv6PortAndVerboseRequest() throws {
        let target = FingerTarget(host: "2001:db8::1", port: 7979, request: "alice", verbose: true)

        XCTAssertEqual(target.canonicalURL?.absoluteString, "finger://[2001:db8::1]:7979/%2FW%20alice")
    }
}

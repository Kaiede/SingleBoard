import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        // Core
        testCase(SingleBoardTests.allTests),

        // Raspberry Pi
        testCase(RaspberryPiRegisterTests.allTests),
    ]
}
#endif
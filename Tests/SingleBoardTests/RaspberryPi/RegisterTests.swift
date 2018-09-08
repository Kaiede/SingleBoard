import XCTest
@testable import SingleBoard

final class RaspberryPiRegisterTests: XCTestCase {
    func testSizes() {
        // Assert that our memory size matches the memory registers
        // As long as this passes, it is safe to back UnsafeMutablePointer
        // with these types on the Raspberry Pi.

        // GPIO
        XCTAssertEqual(MemoryLayout<RaspberryGPIOSet>.size, 4)
        XCTAssertEqual(MemoryLayout<RaspberryGPIOClear>.size, 4)
        XCTAssertEqual(MemoryLayout<RaspberryGPIOLevels>.size, 4)

        XCTAssertEqual(MemoryLayout<RaspberryGPIOPullup>.size, 4)
        XCTAssertEqual(MemoryLayout<RaspberryGPIOModeSet>.size, 4)

        // Clock`
        XCTAssertEqual(MemoryLayout<RaspberryClkDivisor>.size, 4)
        XCTAssertEqual(MemoryLayout<RaspberryClkCtrl>.size, 4)

        // PWM
        XCTAssertEqual(MemoryLayout<RaspberryPWMCtrl>.size, 4)
        XCTAssertEqual(MemoryLayout<RaspberryPWMRange>.size, 4)
        XCTAssertEqual(MemoryLayout<RaspberryPWMData>.size, 4)
    }

    func testGpioModeSet() {
        let testRegister = UnsafeMutablePointer<RaspberryGPIOModeSet>.allocate(capacity: 1)
        let underlyingRegister = UnsafeMutableRawPointer(testRegister).bindMemory(to: UInt32.self, capacity: 1)

        // Initialize
        underlyingRegister.pointee = 0

        // Apply Changes
        testRegister.pointee[0] = .output
        testRegister.pointee[9] = .alt3

        XCTAssertEqual(underlyingRegister.pointee, 0b00111000000000000000000000000001)
    }

    func testGpioPullup() {
        let testRegister = UnsafeMutablePointer<RaspberryGPIOPullup>.allocate(capacity: 1)
        let underlyingRegister = UnsafeMutableRawPointer(testRegister).bindMemory(to: UInt32.self, capacity: 1)

        // Initialize
        underlyingRegister.pointee = 0

        // Case 1: Manipulation
        testRegister.pointee = .pullUp
        XCTAssertEqual(underlyingRegister.pointee, 0b10)
    }

    func testClockControl() {
        let testRegister = UnsafeMutablePointer<RaspberryClkCtrl>.allocate(capacity: 1)
        let underlyingRegister = UnsafeMutableRawPointer(testRegister).bindMemory(to: UInt32.self, capacity: 1)
        testRegister.pointee = [.password, .sourcePLLD, .enable]

        // Case 1: Extract the Source
        XCTAssertEqual(testRegister.pointee.source, .sourcePLLD)

        // Case 2: Proper 32-bit Layout
        XCTAssertEqual(underlyingRegister.pointee, 0x5A000016)
    }

    func testClockDivisor() {
        let testRegister = UnsafeMutablePointer<RaspberryClkDivisor>.allocate(capacity: 1)
        let underlyingRegister = UnsafeMutableRawPointer(testRegister).bindMemory(to: UInt32.self, capacity: 1)

        // Case 1: Default Input
        testRegister.pointee = RaspberryClkDivisor(divi: 2)
        XCTAssertEqual(underlyingRegister.pointee, 0x5A002000)

        // Case 2: Full Input
        testRegister.pointee = RaspberryClkDivisor(divi: 0x123, divf: 0x123)
        XCTAssertEqual(underlyingRegister.pointee, 0x5A123123)

        // Case 3: Manipulation
        underlyingRegister.pointee = 0
        testRegister.pointee.divi = 2
        XCTAssertEqual(underlyingRegister.pointee, 0x5A002000)
    }



    static var allTests = [
        ("testSizes", testSizes),
        ("testGpioModeSet", testGpioModeSet),
        ("testGpioPullup", testGpioPullup),
        ("testClockControl", testClockControl),
        ("testClockDivisor", testClockDivisor)
    ]
}

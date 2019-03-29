import XCTest
@testable import SingleBoard

final class SingleBoardTests: XCTestCase {
    enum TestCommand: UInt8 {
        case commandOne = 0x01
        case commandTwo = 0x02
    }

    struct TestOptionByte: OptionSet {
        let rawValue: UInt8

        static let testSetting = TestOptionByte(rawValue: 1 << 4)
    }

    struct TestOptionWord: OptionSet {
        let rawValue: UInt16

        static let testSetting = TestOptionWord(rawValue: 1 << 12)
    }


    enum TestByte: UInt8 {
        case testSetting = 0xA5
    }

    enum TestWord: UInt16 {
        case testSetting = 0xF0F0
    }


    class MockI2CEndpoint: BoardI2CEndpoint {
        var lastCommand: UInt8 = 0
        var bufferByte: UInt8 = 0
        var bufferWord: UInt16 = 0
        var bufferData: Data = Data()
        
        var reachable: Bool {
            return true
        }
        
        func readByte() -> UInt8 {
            return bufferByte
        }

        func readWord() -> UInt16 {
            return bufferWord
        }

        func readData(length: Int) -> Data {
            return bufferData
        }

        public func decode<T: I2CReadable>() -> T {
            return T(data: bufferData)
        }

        func writeByte(value: UInt8) {
            self.bufferByte = value
        }

        func writeWord(value: UInt16) {
            self.bufferWord = value
        }

        func writeData(value: Data) {
            self.bufferData = value
        }

        public func encode<T: I2CWritable>(value: T) {
            self.bufferData = value.encodeToData()
        } 
        
        func readByte(command: UInt8) -> UInt8 {
            self.lastCommand = command
            return bufferByte
        }
        
        func readWord(command: UInt8) -> UInt16 {
            self.lastCommand = command
            return bufferWord
        }

        func readData(command: UInt8) -> Data {
            self.lastCommand = command
            return bufferData
        }

        public func decode<T: I2CReadable>(command: UInt8) -> T {
            self.lastCommand = command
            return T(data: bufferData)
        }
        
        func writeQuick() {}
        
        func writeByte(command: UInt8, value: UInt8) {
            self.lastCommand = command
            self.bufferByte = value
        }
        
        func writeWord(command: UInt8, value: UInt16) {
            self.lastCommand = command
            self.bufferWord = value
        }

        func writeData(command: UInt8, value: Data) {
            self.lastCommand = command
            self.bufferData = value
        }

        public func encode<T: I2CWritable>(command: UInt8, value: T) {
            self.lastCommand = command
            self.bufferData = value.encodeToData()
        }
    }
    

    func testReadWithEnums() {
        let mockEndpoint = MockI2CEndpoint()

        mockEndpoint.bufferByte = 0xA5
        mockEndpoint.bufferWord = 0xF0F0

        let testByte: TestByte? = mockEndpoint.read(command: TestCommand.commandOne)
        XCTAssertEqual(testByte, .testSetting)
        XCTAssertEqual(mockEndpoint.lastCommand, TestCommand.commandOne.rawValue)

        let testWord: TestWord? = mockEndpoint.read(command: TestCommand.commandTwo)
        XCTAssertEqual(testWord, .testSetting)
        XCTAssertEqual(mockEndpoint.lastCommand, TestCommand.commandTwo.rawValue)
    }

    func testReadWithOptionSet() {
        let mockEndpoint = MockI2CEndpoint()

        mockEndpoint.bufferByte = 0x10
        mockEndpoint.bufferWord = 0x1000

        let testByte: TestOptionByte = mockEndpoint.read(command: TestCommand.commandOne)
        XCTAssertEqual(testByte, .testSetting)
        XCTAssertEqual(mockEndpoint.lastCommand, TestCommand.commandOne.rawValue)

        let testWord: TestOptionWord = mockEndpoint.read(command: TestCommand.commandTwo)
        XCTAssertEqual(testWord, .testSetting)
        XCTAssertEqual(mockEndpoint.lastCommand, TestCommand.commandTwo.rawValue)
    }

    func testWriteWithEnums() {
        let mockEndpoint = MockI2CEndpoint()

        mockEndpoint.write(command: TestCommand.commandOne, value: TestOptionByte.testSetting)
        XCTAssertEqual(mockEndpoint.bufferByte, 0x10)
        XCTAssertEqual(mockEndpoint.lastCommand, 1)

        mockEndpoint.write(command: TestCommand.commandTwo, value: TestOptionWord.testSetting)
        XCTAssertEqual(mockEndpoint.bufferWord, 0x1000)
        XCTAssertEqual(mockEndpoint.lastCommand, 2)
    }

    static var allTests = [
        ("testReadWithEnums", testReadWithEnums),
        ("testReadWithOptionSet", testReadWithOptionSet),
        ("testWriteWithEnums", testWriteWithEnums),
    ]
}

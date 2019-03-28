/*
 SingleBoard - Common

 Copyright (c) 2018 Adam Thayer
 SwiftyGPIO I2C Implementation Copyright (c) 2017 Umberto Raimondi

 Licensed under the MIT license, as follows:

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.)
 */

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import Foundation

public extension BoardI2CEndpoint {
    // Convenience for Data
    func readData(from command: UInt8) -> Data {
        return Data(bytes: self.readByteArray(from: command))
    }

    func writeData(to command: UInt8, value: Data) {
        self.writeByteArray(to: command, value: [UInt8](value))
    }

    func writeData<T: RawRepresentable>(to command: T, value: Data)
        where T.RawValue == UInt8
    {
        self.writeByteArray(to: command.rawValue, value: [UInt8](value))
    }
    
    // Convenience for Command Enums
    func readByte<T: RawRepresentable>(from command: T) -> UInt8
        where T.RawValue == UInt8
    {
        return self.readByte(from: command.rawValue)
    }
    
    func readWord<T: RawRepresentable>(from command: T) -> UInt16
        where T.RawValue == UInt8
    {
        return self.readWord(from: command.rawValue)
    }
    
    func writeByte<T: RawRepresentable>(to command: T, value: UInt8)
        where T.RawValue == UInt8
    {
        return self.writeByte(to: command.rawValue, value: value)
    }
    
    func writeWord<T: RawRepresentable>(to command: T, value: UInt16)
        where T.RawValue == UInt8
    {
        return self.writeWord(to: command.rawValue, value: value)
    }
    
    // Read in Enums and OptionSets
    func read<T: RawRepresentable>() -> T?
        where T.RawValue == UInt8
    {
        return T(rawValue: self.readByte())
    }

    func read<T: RawRepresentable>() -> T?
        where T.RawValue == UInt16
    {
        return T(rawValue: self.readWord())
    }

    func read<T: RawRepresentable, U: RawRepresentable>(from command: T) -> U?
        where T.RawValue == UInt8, U.RawValue == UInt8
    {
        return U(rawValue: self.readByte(from: command.rawValue))
    }

    func read<T: RawRepresentable, U: RawRepresentable>(from command: T) -> U?
        where T.RawValue == UInt8, U.RawValue == UInt16
    {
        return U(rawValue: self.readWord(from: command.rawValue))
    }

    func read<T: RawRepresentable, U: OptionSet>(from command: T) -> U
        where T.RawValue == UInt8, U.RawValue == UInt8
    {
        return U(rawValue: self.readByte(from: command.rawValue))
    }

    func read<T: RawRepresentable, U: OptionSet>(from command: T) -> U
        where T.RawValue == UInt8, U.RawValue == UInt16
    {
        return U(rawValue: self.readWord(from: command.rawValue))
    }

    // Write Enums and OptionSets
    func write<T: RawRepresentable>(value: T)
        where T.RawValue == UInt8
    {
        return self.writeByte(value: value.rawValue)
    }

    func write<T: RawRepresentable>(value: T)
        where T.RawValue == UInt16
    {
        return self.writeWord(value: value.rawValue)
    }

    func write<T: RawRepresentable, U: RawRepresentable>(to command: T, value: U)
        where T.RawValue == UInt8, U.RawValue == UInt8
    {
        return self.writeByte(to: command.rawValue, value: value.rawValue)
    }

    func write<T: RawRepresentable, U: RawRepresentable>(to command: T, value: U)
        where T.RawValue == UInt8, U.RawValue == UInt16
    {
        return self.writeWord(to: command.rawValue, value: value.rawValue)
    }
}

// This would normally be easier in Swift 4:
// extension Dictionary: BoardI2C where Key == Int, Value == BoardI2CChannel {}
class SysI2CBoard: BoardI2CBusSet {
    let mainBus: BoardI2CBus
    private let buses: [Int: BoardI2CBus]

    init(range: CountableClosedRange<Int>, mainBus: BoardI2CBus) {
        var buses: [Int: BoardI2CBus] = [:]
        for index in range {
            if mainBus.busId == index {
                buses[index] = mainBus
            } else {
                buses[index] = SysI2CBus(busIndex: index)
            }
        }

        self.buses = buses
        self.mainBus = mainBus
    }

    init(buses: [Int: BoardI2CBus], mainBus: BoardI2CBus) {
        self.buses = buses
        self.mainBus = mainBus
    }

    subscript(busIndex: Int) -> BoardI2CBus? {
        return buses[busIndex]
    }
}

public final class SysI2CBus: BoardI2CBus {
    private static let I2C_SLAVE: UInt = 0x703
    private static let I2C_SLAVE_FORCE: UInt = 0x706
    private static let I2C_RDWR: UInt = 0x707
    private static let I2C_PEC: UInt = 0x708
    private static let I2C_SMBUS: UInt = 0x720
    private static let I2C_MAX_LENGTH: Int = 32

    public let busId: Int
    private var fdI2C: Int32 = -1
    private var currentEndpoint: UInt8?
    private var activeEndpoints: [UInt8: BoardI2CEndpoint] = [:]

    public init(busIndex: Int) {
        self.busId = busIndex
    }

    deinit {
        if fdI2C != -1 {
            close(fdI2C)
        }
    }

    public func isReachable(address: UInt8) -> Bool {
        return self[address].reachable
    }

    public subscript(address: UInt8) -> BoardI2CEndpoint {
        if let endpoint = self.activeEndpoints[address] {
            return endpoint
        }

        let endpoint = SysI2CEndpoint(address: address, controller: self)
        self.activeEndpoints[address] = endpoint
        return endpoint
    }

    fileprivate func openChannel() {
        let filePath: String = "/dev/i2c-\(self.busId)"

        let fdI2C = open(filePath, O_RDWR)
        guard fdI2C > 0 else {
            fatalError()
        }

        self.fdI2C = fdI2C
    }

    // MARK: I2C Read/Write
    fileprivate func readByte(at address: UInt8) -> UInt8? {
        var data = [UInt8](repeating: 0, count: 1)
        guard i2cIoctl(.read, address: address, length: UInt16(data.count), data: &data) else { return nil }
        return data[0]
    }

    fileprivate func readWord(at address: UInt8) -> UInt16? {
        var data = [UInt8](repeating: 0, count: 2)
        guard i2cIoctl(.read, address: address, length: UInt16(data.count), data: &data) else { return nil }
        return (UInt16(data[1]) << 8) + UInt16(data[0])
    }

    fileprivate func readByteArray(at address: UInt8, length: UInt8) -> [UInt8]? {
        var data = [UInt8](repeating:0, count: Int(length))
        guard i2cIoctl(.read, address: address, length: UInt16(data.count), data: &data) else { return nil }
        return data
    }

    fileprivate func writeByte(at address: UInt8, value: UInt8) -> Bool {
        var data = [UInt8](repeating:0, count: 1)

        data[0] = value
        return i2cIoctl(.write, address: address, length: 1, data: &data)
    }

    fileprivate func writeWord(at address: UInt8, value: UInt16) -> Bool {
        var data = [UInt8](repeating:0, count: 2)

        data[0] = UInt8(value & 0xFF)
        data[1] = UInt8(value >> 8)
        return i2cIoctl(.write, address: address, length: 2, data: &data)
    }

    fileprivate func writeByteArray(at address: UInt8, value: [UInt8]) -> Bool {
        guard value.count <= SysI2CBus.I2C_MAX_LENGTH else { return false }

        var data = value
        return i2cIoctl(.write, address: address, length: UInt16(value.count), data: &data)
    }

    fileprivate func i2cIoctl(_ readOrWrite: SMBusReadWrite, address: UInt8, length: UInt16, data: UnsafeMutablePointer<UInt8>?) -> Bool {
        if self.fdI2C == -1 {
            self.openChannel()
        }

        let flags: I2CMessageFlags = readOrWrite.isRead ? [.read] : []

        var message = I2CMessage(UInt16(address), flags: flags, length: length, data: data)
        var messageSet = I2CMessageSet(&message, count: 1)
        guard ioctl(fdI2C, SysI2CBus.I2C_RDWR, &messageSet) >= 0 else {
            print("I2C_RDWR Error: \(errno)")
            return false
        }
        return true
    }

    // MARK: SMBus Read/Write
    fileprivate func setCurrentEndpoint(to address: UInt8) {
        if self.fdI2C == -1 {
            self.openChannel()
        }

        guard self.currentEndpoint != address else { return }

        let result = ioctl(fdI2C, SysI2CBus.I2C_SLAVE_FORCE, CInt(address))
        guard result == 0 else {
            fatalError()
        }

        self.currentEndpoint = address
    }

    fileprivate func readByte(from command: UInt8) -> UInt8? {
        var data = [UInt8](repeating:0, count: SysI2CBus.I2C_MAX_LENGTH+1)

        guard smbusIoctl(.read, command: command, dataKind: .byteData, data: &data) else { return nil }
        return data[0]
    }

    fileprivate func readWord(from command: UInt8) -> UInt16? {
        var data = [UInt8](repeating:0, count: SysI2CBus.I2C_MAX_LENGTH+1)

        guard smbusIoctl(.read, command: command, dataKind: .wordData, data: &data) else { return nil }
        return (UInt16(data[1]) << 8) + UInt16(data[0])
    }

    fileprivate func readByteArray(from command: UInt8) -> [UInt8]? {
        var data = [UInt8](repeating:0, count: SysI2CBus.I2C_MAX_LENGTH+1)

        guard smbusIoctl(.read, command: command, dataKind: .blockData, data: &data) else { return nil }
        let lenData = Int(data[0])
        return Array(data[1...lenData])
    }

    fileprivate func writeQuick() -> Bool {
        return smbusIoctl(.write, command: 0, dataKind: .quick, data: nil)
    }

    fileprivate func writeByte(to command: UInt8, value: UInt8) -> Bool {
        var data = [UInt8](repeating:0, count: SysI2CBus.I2C_MAX_LENGTH+1)

        data[0] = value
        guard smbusIoctl(.write, command: command, dataKind: .byteData, data: &data) else { return false }
        return true
    }

    fileprivate func writeWord(to command: UInt8, value: UInt16) -> Bool {
        var data = [UInt8](repeating:0, count: SysI2CBus.I2C_MAX_LENGTH+1)

        data[0] = UInt8(value & 0xFF)
        data[1] = UInt8(value >> 8)

        guard smbusIoctl(.write, command: command, dataKind: .wordData, data: &data) else { return false }
        return true
    }

    fileprivate func writeByteArray(to command: UInt8, value: [UInt8]) -> Bool {
        guard value.count <= SysI2CBus.I2C_MAX_LENGTH else { return false }
        var data = [UInt8](repeating:0, count: SysI2CBus.I2C_MAX_LENGTH+1)

        for i in 1...value.count {
            data[i] = value[i - 1]
        }
        data[0] = UInt8(value.count)
        guard smbusIoctl(.write, command: command, dataKind: .blockData, data: &data) else { return false }
        return true
    }

    fileprivate func smbusIoctl(_ readOrWrite: SMBusReadWrite, command: UInt8, dataKind: SMBusDataKind, data: UnsafeMutablePointer<UInt8>?) -> Bool {
        if self.fdI2C == -1 {
            self.openChannel()
        }

        var args = SMBusData(readOrWrite, command: command, dataKind: dataKind, data: data)
        guard ioctl(self.fdI2C, SysI2CBus.I2C_SMBUS, &args) >= 0 else { 
            print("I2C_SMBUS Error: \(errno)")
            return false
                }
        return true
    }
}

public final class SysI2CEndpoint: BoardI2CEndpoint {
    private let address: UInt8
    private let controller: SysI2CBus

    init(address: UInt8, controller: SysI2CBus) {
        self.address = address
        self.controller = controller
    }

    public var reachable: Bool {
        controller.setCurrentEndpoint(to: address)

        return controller.readByte(from: 0) != nil
    }

    //
    // Generic I2C
    //

    public func readByte() -> UInt8 {
        guard let byte = controller.readByte(at: address) else { fatalError() }
        return byte
    }

    public func readWord() -> UInt16 {
        guard let word = controller.readWord(at: address) else { fatalError() }
        return word
    }

    fileprivate func readByteArray(length: UInt8) -> [UInt8] {
        guard let data = controller.readByteArray(at: address, length: length) else { fatalError() }
        return data
    }

    public func decode<T: I2CReadable>() -> T {
        guard let data = controller.readByteArray(at: address, length: UInt8(T.i2cReadLength)) else { fatalError() }
        return T(i2cBuffer: data)
    }

    public func writeByte(value: UInt8) {
        guard controller.writeByte(at: address, value: value) else { fatalError() }
    }

    public func writeWord(value: UInt16) {
        guard controller.writeWord(at: address, value: value) else { fatalError() }
    }

    fileprivate func writeByteArray(value: [UInt8]) {
        guard controller.writeByteArray(at: address, value: value) else { fatalError() }
    }

    public func encode<T>(value: T) where T : I2CWritable {
        guard controller.writeByteArray(at: address, value: value.encodeToBuffer()) else { fatalError() }
    }

    //
    // SMBus
    //

    public func readByte(from command: UInt8) -> UInt8 {
        controller.setCurrentEndpoint(to: address)

        guard let byte = controller.readByte(from: command) else { fatalError() }
        return byte
    }

    public func readWord(from command: UInt8) -> UInt16 {
        controller.setCurrentEndpoint(to: address)

        guard let word = controller.readWord(from: command) else { fatalError() }
        return word
    }

    public func readByteArray(from command: UInt8) -> [UInt8] {
        controller.setCurrentEndpoint(to: address)

        guard let byteArray = controller.readByteArray(from: command) else { fatalError() }
        return byteArray
    }

    public func decode<T: I2CReadable>(from command: UInt8) -> T {
        controller.setCurrentEndpoint(to: address)

        guard let byteArray = controller.readByteArray(from: command) else { fatalError() }
        return T(i2cBuffer: byteArray)
    }

    public func writeQuick() {
        controller.setCurrentEndpoint(to: address)

        guard controller.writeQuick() else { fatalError() }
    }

    public func writeByte(to command: UInt8, value: UInt8) {
        controller.setCurrentEndpoint(to: address)

        guard controller.writeByte(to: command, value: value) else { fatalError() }
    }

    public func writeWord(to command: UInt8, value: UInt16) {
        controller.setCurrentEndpoint(to: address)

        guard controller.writeWord(to: command, value: value) else { fatalError() }
    }

    public func encode<T>(to command: UInt8, value: T) where T : I2CWritable {
        controller.setCurrentEndpoint(to: address)

        guard controller.writeByteArray(to: command, value: value.encodeToBuffer()) else { fatalError() }
    }

    public func writeByteArray(to command: UInt8, value: [UInt8]) {
        controller.setCurrentEndpoint(to: address)

        guard controller.writeByteArray(to: command, value: value) else { fatalError() }
    }
}

struct I2CMessageFlags: OptionSet {
    let rawValue: UInt16

    static let read = I2CMessageFlags(rawValue: 0x0001)
    static let noStart = I2CMessageFlags(rawValue: 0x4000)
}

struct I2CMessage {
    var address: UInt16
    var flags: I2CMessageFlags
    var length: UInt16
    var data: UnsafeMutablePointer<UInt8>?

    init(_ address: UInt16, flags: I2CMessageFlags, length: UInt16, data: UnsafeMutablePointer<UInt8>?) {
        self.address = address
        self.flags = flags
        self.length = length
        self.data = data
    }
}

struct I2CMessageSet {
    var messages: UnsafeMutablePointer<I2CMessage>?
    var count: UInt32

    init(_ messages: UnsafeMutablePointer<I2CMessage>?, count: Int) {
        self.messages = messages
        self.count = UInt32(count)
    }
}

struct SMBusReadWrite {
    let rawValue: UInt8

    private init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    var isRead: Bool {
        get { return self.rawValue != 0 }
    }

    static let read = SMBusReadWrite(rawValue: 1)
    static let write = SMBusReadWrite(rawValue: 0)
}

enum SMBusDataKind: Int32 {
    case quick = 0
    case byte = 1
    case byteData = 2
    case wordData = 3
    case blockData = 5
}

fileprivate struct SMBusData {
    var readOrWrite: SMBusReadWrite
    var command: UInt8
    var dataKind: Int32
    var data: UnsafeMutablePointer<UInt8>?

    init(_ readOrWrite: SMBusReadWrite, command: UInt8, dataKind: SMBusDataKind, data: UnsafeMutablePointer<UInt8>?) {
        self.readOrWrite = readOrWrite
        self.command = command
        self.dataKind = dataKind.rawValue
        self.data = data
    }
}

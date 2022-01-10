/*
 MCP4725

 Copyright (c) 2019 Adam Thayer
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
import SingleBoard

public class MCP4725 {
    // These defaults are used by the Aptinex and ncd.io boards that use this chip.
    public static let defaultAddress: UInt8 = 0x62
    public static let defaultHighAddress: UInt8 = 0x63

    public enum PowerDownMode : UInt8 {
        case normal         = 0b00
        case powerDown1k    = 0b01
        case powerDown100k  = 0b10
        case powerDown500k  = 0b11
    }

    internal struct FastModeData: I2CWritable {
        static var dataLength: Int = MemoryLayout<UInt16>.size
        var mode: PowerDownMode
        var voltage: UInt16

        init(voltage: UInt16, mode: PowerDownMode) {
            self.voltage = voltage
            self.mode = mode
        }

        func encodeToData() -> Data {
            var data = Data(capacity: FastModeData.dataLength)
            data.append(UInt8(mode.rawValue << 4) | UInt8(self.voltage & 0x0F00))
            data.append(UInt8(self.voltage & 0xFF))
            return data
        }
    }

    internal enum WriteCommand: UInt8 {
        case writeDac = 0b010
        case writeDacAndRom = 0b011
    }

    internal struct FullData: I2CReadWritable {
        static var dataLength: Int = MemoryLayout<UInt8>.size * 3

        var command: WriteCommand
        var voltage: UInt16
        var mode: PowerDownMode

        // Only set on decode
        var ready: Bool

        // Read Initializer
        init(data: Data) {
            self.command = .writeDac
            self.mode = PowerDownMode(rawValue: data[0] >> 1 & 0x3) ?? .normal
            self.ready = data[0] & 0x80 != 0
            self.voltage = UInt16(data[1]) << 4 + UInt16(data[2]) >> 4
        }

        // Write Initializer
        init(command: WriteCommand, voltage: UInt16, mode: PowerDownMode) {
            self.ready = false
            self.command = command
            self.voltage = voltage
            self.mode = mode
        }

        func encodeToData() -> Data {
            var data = Data(capacity: FullData.dataLength)
            data.append(self.command.rawValue << 5 + self.mode.rawValue << 1)
            data.append(UInt8(self.voltage & 0xFFF >> 4))
            data.append(UInt8(self.voltage & 0xF << 4))
            return data
        }
    }

    private let endpoint: BoardI2CEndpoint

    public init(i2cBus: BoardI2CBus, address: UInt8 = defaultAddress) {
        self.endpoint = i2cBus[address]
        guard self.endpoint.reachable else {
            fatalError("I2C Address is Unreachable")
        }
    }

    public func set(voltage: UInt16, mode: PowerDownMode = .normal) {
        let result = FastModeData(voltage: voltage, mode: mode)
        self.endpoint.encode(value: result)
    }

    public func setDefault(voltage: UInt16, mode: PowerDownMode = .normal) {
        waitForReady()
        let result = FullData(command: .writeDacAndRom, voltage: voltage, mode: mode)
        self.endpoint.encode(value: result)
    }

    public func readVoltage() -> (UInt16, PowerDownMode) {
        let result = readFromChip()
        return (result.voltage, result.mode)
    }

    private func waitForReady() {
        var result = readFromChip()
        while !result.ready {
            usleep(5000)
            result = readFromChip()
        }
    }

    private func readFromChip() -> FullData {
        let result: FullData = self.endpoint.decode()
        return result
    }
}

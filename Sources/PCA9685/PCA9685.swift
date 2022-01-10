/*
 PCA9685

 Copyright (c) 2018 Adam Thayer
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

import SingleBoard

enum Register: UInt8 {
    case mode1       = 0x00
    case mode2       = 0x01
    case subAdr1     = 0x02
    case subAdr2     = 0x03
    case subAdr3     = 0x04
    case prescale    = 0xFE
    case ledOnBase   = 0x06 // Word
    case ledOffBase  = 0x08 // Word
    case allLedOn    = 0xFA // Word
    case allLedOff   = 0xFC // Word

    func offsetBy(_ offset: Int) -> UInt8 {
        return UInt8(Int(self.rawValue) + offset)
    }
}

struct Mode1: OptionSet {
    let rawValue: UInt8

    static let allCall     = Mode1(rawValue: 0x01)
    static let sleep       = Mode1(rawValue: 0x10)
    static let autoInc     = Mode1(rawValue: 0x20)
    static let restart     = Mode1(rawValue: 0x80)
}

struct Mode2: OptionSet {
    let rawValue: UInt8

    static let outDrv      = Mode2(rawValue: 0x04)
    static let invert      = Mode2(rawValue: 0x10)
}

public class PCA9685 {
    public static let defaultAdafruitAddress: UInt8 = 0x40

    public var frequency: UInt {
        didSet {
            self.onFrequencyChanged()
        }
    }

    private let endpoint: BoardI2CEndpoint

    public init(i2cBus: BoardI2CBus, address: UInt8 = defaultAdafruitAddress) {
        self.frequency = 0
        
        self.endpoint = i2cBus[address]
        guard self.endpoint.reachable else {
            fatalError("I2C Address is Unreachable")
        }

        // Now, Configure the PCA9685
        self.setAllChannels(onStep: 0, offStep: 0)
        self.endpoint.write(command: Register.mode2, value: Mode2.outDrv)
        self.endpoint.write(command: Register.mode1, value: Mode1.allCall)

        // Wait for Oscillator
        usleep(5)

        // Reset Sleep, Set Auto Increment (for writeWord)
        let mode1: Mode1 = self.endpoint.read(command: Register.mode1)
        let setupMode1 = mode1.subtracting([.sleep]).union([.autoInc])
        self.endpoint.write(command: Register.mode1, value: setupMode1)

        // Wait for Oscillator
        usleep(5)
    }

    public func setChannel(_ channel: UInt8, onStep: UInt16, offStep: UInt16) {
        guard channel < 16 else { fatalError("channel must be 0-15") }

        let commandOn = Register.ledOnBase.offsetBy(4 * Int(channel))
        let commandOff = Register.ledOffBase.offsetBy(4 * Int(channel))

        self.endpoint.writeWord(command: commandOn, value: onStep)
        self.endpoint.writeWord(command: commandOff, value: offStep)
    }

    public func setAllChannels(onStep: UInt16, offStep: UInt16) {
        self.endpoint.writeWord(command: Register.allLedOn, value: onStep)
        self.endpoint.writeWord(command: Register.allLedOff, value: offStep)
    }

    func onFrequencyChanged() {
        // Calculate Prescale
        var prescaleFlt = 25000000.0    // 25MHz
        prescaleFlt /= 4096.0           // 12-Bit
        prescaleFlt /= Double(self.frequency)
        prescaleFlt -= 1.0

        let prescale = UInt8(prescaleFlt + 0.5)

        // Go To Sleep & Set Prescale
        let mode1: Mode1 = self.endpoint.read(command: Register.mode1)
        let sleepMode = mode1.subtracting([.restart]).union([.sleep])
        self.endpoint.write(command: Register.mode1, value: sleepMode)
        self.endpoint.writeByte(command: Register.prescale, value: prescale)
        self.endpoint.write(command: Register.mode1, value: mode1)

        usleep(5)

        // Restart
        let restartMode = mode1.union([.restart])
        self.endpoint.write(command: Register.mode1, value: restartMode)
    }
}

/*
 SingleBoard

 Copyright (c) 2018 Adam Thayer
 SwiftyGPIO Copyright (c) 2016 Umberto Raimondi

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

import Foundation

public struct SingleBoard {
    public static let raspberryPi: RaspberryCapabilities = { return RaspberryBoard() }()

    public static let pine64: PineCapabilities = { return Pine64Board() }()
    public static let rock64: PineCapabilities = { return Rock64Board() }()

    public static let chip: ChipCapabilities = { return ChipBoard() }()
}

//
// MARK: Board Capabilities
//
// By splitting out capabilities, it is possible to avoid including optionals,
// and enforce consistent behavior at the same time.
public typealias RaspberryCapabilities = HasGPIO & HasI2C & HasPWM
public typealias PineCapabilities      = HasI2C
public typealias ChipCapabilities      = HasI2C 

//
// MARK: GPIO Access
//
// More Types in Common/GPIO.swift
public protocol HasGPIO: class {
    var gpio: BoardGPIO { get }
}

public protocol BoardGPIO: class {
    subscript(pins: PinSet) -> BoardGPIOPinSet { get }
    subscript(pin: PinIndex) -> BoardGPIOPin { get }
}

public protocol BoardGPIOPin: class {
    var value: Bool { get set }
    var mode: PinMode { get set }

    func setPullup(_ pullup: PinPullup)
}

public protocol BoardGPIOPinSet: class {
    var value: Bool { get set }

    func setMode(_ mode: PinMode)
    func setPullup(_ pullup: PinPullup)
}

//
// MARK: I2C Access
//
// More Convenience Extensions in Common/I2C.swift
public protocol HasI2C: class {
    var i2cMainBus: BoardI2CBus { get }
    var i2cBus: BoardI2CBusSet { get }
}

public protocol BoardI2CBusSet: class {
    subscript(busIndex: Int) -> BoardI2CBus? { get }
}

public protocol BoardI2CBus: class {
    var busId: Int { get }

    func isReachable(address: UInt8) -> Bool

    subscript(address: UInt8) -> BoardI2CEndpoint { get }
}

public protocol I2CReadable
{
    static var dataLength: Int { get }
    init(data: Data)
}

public protocol I2CWritable
{
    func encodeToData() -> Data
}

public protocol I2CReadWritable: I2CReadable, I2CWritable {}

public protocol BoardI2CEndpoint: class {
    var reachable: Bool { get }

    // Generic I2C
    func readByte() -> UInt8
    func readWord() -> UInt16
    func readData(length: Int) -> Data
    func decode<T: I2CReadable>() -> T

    func writeByte(value: UInt8)
    func writeWord(value: UInt16)
    func writeData(value: Data)
    func encode<T: I2CWritable>(value: T)

    // SMBus
    func readByte(command: UInt8) -> UInt8
    func readWord(command: UInt8) -> UInt16
    func readData(command: UInt8) -> Data
    func decode<T: I2CReadable>(command: UInt8) -> T

    func writeQuick()
    func writeByte(command: UInt8, value: UInt8)
    func writeWord(command: UInt8, value: UInt16)
    func writeData(command: UInt8, value: Data)
    func encode<T: I2CWritable>(command: UInt8, value: T)
}

//
// MARK: PWM Access
//
public protocol HasPWM: class {
    var pwm: BoardPWM { get }
}

public protocol BoardPWM: class {
    var count: Int { get }

    func enable()
    func disable()

    subscript(channel: Int) -> BoardPWMChannel { get }
}

public protocol BoardPWMChannel: class {
    var pins: PinSet { get }

    func enable(pins: PinSet)
    func enable(pin: PinIndex)

    func start(period: UInt, dutyCycle: Float)
    func stop()
}

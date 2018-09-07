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
    public static let raspberryPi: Board = { return RaspberryBoard() }()
}

//
// MARK: The Root Of It All
//
public protocol Board {
	var gpio: BoardGPIO? { get }
	var i2c: BoardI2C? { get }
	var pwm: BoardPWM? { get }
}

//
// MARK: GPIO Access
//
// More Types in Common/GPIO.swift
public protocol BoardGPIO {
	subscript(pins: PinSet) -> BoardGPIOPinSet { get }
	subscript(pin: PinIndex) -> BoardGPIOPinSet { get }
}

public protocol BoardGPIOPinSet {
	var value: Bool { get set }
	var activeLow: Bool { get set }
	var mode: PinMode { get set }
	var pullup: PinPullup { get set }
}

//
// MARK: I2C Access
//
// More Convenience Extensions in Common/I2C.swift
public protocol BoardI2C {
	subscript(channel: Int) -> BoardI2CChannel? { get }
}

public protocol BoardI2CChannel {
	func isReachable(address: Int) -> Bool

	subscript(address: Int) -> BoardI2CEndpoint { get }
}

public protocol BoardI2CEndpoint {
	var reachable: Bool { get }

	func readByte() -> UInt8
	func readByte(from: UInt8) -> UInt8
	func readWord(from: UInt8) -> UInt16
	func readByteArray(from: UInt8) -> [UInt8]

	func writeQuick()
	func writeByte(value: UInt8)
	func writeByte(to: UInt8, value: UInt8)
	func writeWord(to: UInt8, value: UInt16)
	func writeByteArray(to: UInt8, value: [UInt8])
}

//
// MARK: PWM Access
//
public protocol BoardPWM {
	var count: Int { get }

	func enable()
	func disable()

	subscript(channel: Int) -> BoardPWMChannel { get }
}

public protocol BoardPWMChannel {
	var pins: PinSet { get }

	func enable(pins: PinSet)
	func enable(pin: PinIndex)

	func start(period: UInt, dutyCycle: Float)
	func stop()
}

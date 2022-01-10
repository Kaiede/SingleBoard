/*
 SingleBoard - Raspberry Pi

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

class RaspberryPWM: BoardPWM {
    private let gpioMem: RaspberryGPIOMem
    private let secureMem: RaspberrySecureGPIOMem

    private var channels: [BoardPWMChannel]
    private var enabled: Bool

    init(gpioMem: RaspberryGPIOMem, secureMem: RaspberrySecureGPIOMem) {
        self.enabled = false

        self.gpioMem = gpioMem
        self.secureMem = secureMem

        self.channels = []
        self.channels.append(RaspberryPWMChannel(channel: 0, controller: self, pins: [.p12, .p18]))
        self.channels.append(RaspberryPWMChannel(channel: 1, controller: self, pins: [.p13, .p19]))
    }

    var count: Int { 
        return channels.count
    }

    func enable() {
        guard !self.enabled else { return }

        self.startClock()
        self.enabled = true
    }

    func disable() {
        self.killClock()
        self.enabled = false
    }

    subscript(channel: Int) -> BoardPWMChannel {
        get {
            return channels[channel]
        }
    }

    fileprivate func enable(pins: PinSet) {
        for pin in pins.indexes() {
            self.enable(pin: UInt32(pin))
        }
    }

    fileprivate func enable(pin: PinIndex) {
        let validPins: [PinIndex: RaspberryGPIOMode] = [
            12: .alt0,
            13: .alt0,
            18: .alt5,
            19: .alt5
        ]

        guard let gpioMode = validPins[pin] else { return }

        let gpioFunction = gpioMem.gpioFunctionBase.advanced(by: pin.asRaspberryFunctionOffset)
        gpioFunction.pointee[pin.asRaspberryFunctionIndex] = gpioMode
    }

    fileprivate func start(channel: Int, period: UInt, dutyCycle: Float) {
        self.enable()

        // @ 250Mhz, one slot in the PWM channel is 4 ns. All valid periods are multiples of that.
        // Pick a range that is at least as large as requested that we can represent, and round the
        // desired duty cycle to the nearest whole slot.
        //
        // Double precision is used here to handle very low frequencies in the range of <15Hz.
        // Otherwise we lose precision calculating data.
        let range = UInt32(max((Double(period) / 4.0).rounded(.awayFromZero), 1))
        let data = min(UInt32((Double(dutyCycle) * Double(range) / 100.0).rounded(.toNearestOrAwayFromZero)), range)

        if channel == 0 {
            secureMem.pwmRange0.pointee = range
            secureMem.pwmData0.pointee = data
            secureMem.pwmCtrl.pointee.formUnion([.enable1, .enableMS1])
        } else {
            secureMem.pwmRange1.pointee = range
            secureMem.pwmData1.pointee = data
            secureMem.pwmCtrl.pointee.formUnion([.enable2, .enableMS2])
        }
    }

    fileprivate func stop(channel: Int) {
        if channel == 0 {
            secureMem.pwmCtrl.pointee.subtract([.enable1, .enableMS1])
        } else {
            secureMem.pwmCtrl.pointee.subtract([.enable2, .enableMS2])
        }
    }

    private func startClock() {
        self.killClock()

        secureMem.clockDivisor.pointee = RaspberryClkDivisor(divi: 2)
        secureMem.clockCtrl.pointee = [.password, .enable, .sourcePLLD]

        usleep(10)
    }

    private func killClock() {
        secureMem.clockCtrl.pointee = [.password, .kill]
        usleep(10)
    }
}

class RaspberryPWMChannel: BoardPWMChannel {
    public let pins: PinSet

    private let channel: Int
    private let controller: RaspberryPWM
    private var configured: Bool

    fileprivate init(channel: Int, controller: RaspberryPWM, pins: PinSet) {
        self.configured = false

        self.channel = channel
        self.controller = controller
        self.pins = pins
    }

    public func enable(pins: PinSet) {
        guard self.pins.contains(pins) else { return }
        controller.enable(pins: pins)
    }

    public func enable(pin: PinIndex) {
        guard let pinSet = PinSet(index: pin), self.pins.contains(pinSet) else { return }
        controller.enable(pin: pin)
    }

    public func start(period: UInt, dutyCycle: Float) {
        controller.start(channel: channel, period: period, dutyCycle: dutyCycle)
    }

    public func stop() {
        controller.stop(channel: channel)
    }
}

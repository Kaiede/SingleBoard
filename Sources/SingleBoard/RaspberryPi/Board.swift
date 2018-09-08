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

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Foundation

class RaspberryBoard: Board {
    public lazy var gpio: BoardGPIO? = {
        return RaspberryGPIOController(gpioMem: self.gpioMem)
    }()
    
    public let i2c: BoardI2C? = {
        let i2c: [Int: BoardI2CController] = [
            0: SysI2CController(channel: 0),
            1: SysI2CController(channel: 1)
        ]
        return SysI2CBoard(controllers: i2c)
    }()
    
    public lazy var pwm: BoardPWM? = {
        return RaspberryPWM(gpioMem: self.gpioMem, secureMem: self.secureMem)
    }()
    
    private lazy var gpioMem: RaspberryGPIOMem = {
        RaspberryGPIOMem(baseAddr: self.baseAddress)
    }()
    
    private lazy var secureMem: RaspberrySecureGPIOMem = {
        return RaspberrySecureGPIOMem(baseAddr: self.baseAddress)
    }()
    
    private lazy var baseAddress: UInt = RaspberryBoard.getBaseAddress()
    
    private static func getBaseAddress() -> UInt {
        var systemInfo = utsname()
        guard 0 == uname(&systemInfo) else { fatalError() }
        
        let machineType = systemInfo.machineString.lowercased()
        switch machineType {
        case "armv6l": return 0x20000000
        case "armv7l": return 0x3F000000
        case "aarch64": return 0x3F000000
        default:
            fatalError()
        }
    }
}

class RaspberryGPIOController: BoardGPIO {
    fileprivate let gpioMem: RaspberryGPIOMem

    init(gpioMem: RaspberryGPIOMem) {
        self.gpioMem = gpioMem
    }

    subscript(pin: PinIndex) -> BoardGPIOPin {
        return RaspberryGPIOSinglePin(pin, controller: self)
    }

    subscript(pins: PinSet) -> BoardGPIOPinSet {
        return RaspberryGPIOMultiPin(pins, controller: self)
    }

    fileprivate func getValue(for pins: PinSet) -> Bool {
        return gpioMem.gpioLevels.pointee.intersection(pins) == pins
    }

    fileprivate func setValue(_ value: Bool, pins: PinSet) {
        if value {
            gpioMem.gpioSet.pointee = pins
        } else {
            gpioMem.gpioClear.pointee = pins
        }
    }

    fileprivate func getMode(for pin: PinIndex) -> RaspberryGPIOMode {
        let gpioFunction = gpioMem.gpioFunctionBase.advanced(by: pin.asRaspberryFunctionOffset)
        return gpioFunction.pointee[pin.asRaspberryFunctionIndex]
    }

    fileprivate func setMode(_ mode: RaspberryGPIOMode, pin: PinIndex) {
        let gpioFunction = gpioMem.gpioFunctionBase.advanced(by: pin.asRaspberryFunctionOffset)
        gpioFunction.pointee[pin.asRaspberryFunctionIndex] = mode
    }

    fileprivate func setPullup(_ pullup: RaspberryGPIOPullup, pins: PinSet) {
        gpioMem.gpioPullup.pointee = pullup
        usleep(10)
        gpioMem.gpioPullupClk.pointee = pins
        usleep(10);
        gpioMem.gpioPullup.pointee = .disabled
        usleep(10);
        gpioMem.gpioPullupClk.pointee = []
    }
}

class RaspberryGPIOMultiPin: BoardGPIOPinSet {
    fileprivate let pinSet: PinSet
    fileprivate let controller: RaspberryGPIOController

    init(_ pinSet: PinSet, controller: RaspberryGPIOController) {
        self.pinSet = pinSet
        self.controller = controller
    }

    var value: Bool {
        get { return controller.getValue(for: self.pinSet) }
        set { controller.setValue(newValue, pins: self.pinSet) }
    }

    func setMode(_ mode: PinMode) {
        for pin in self.pinSet.indexes() {
            controller.setMode(.init(mode: mode), pin: pin)
        }
    }

    func setPullup(_ pullup: PinPullup) {
        controller.setPullup(.init(pullup: pullup), pins: self.pinSet)
    }
}

class RaspberryGPIOSinglePin: RaspberryGPIOMultiPin, BoardGPIOPin {
    private let pin: PinIndex

    init(_ pin: PinIndex, controller: RaspberryGPIOController) {
        guard let pinSet = PinSet(index: pin) else {
            fatalError("Pin Must Be 31 or Less")
        }

        self.pin = pin
        super.init(pinSet, controller: controller)
    }

    var mode: PinMode {
        get { return PinMode(raspberryMode: controller.getMode(for: self.pin)) }
        set { self.setMode(newValue) }
    }

    override func setMode(_ mode: PinMode) {
        controller.setMode(.init(mode: mode), pin: self.pin)
    }
}

extension PinMode {
    init(raspberryMode mode: RaspberryGPIOMode) {
        switch mode {
        case .output: self = .output
        default:      self = .input
        }
    }
}

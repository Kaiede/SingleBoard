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
    import Darwin.C
#endif

extension PinIndex {
    var asRaspberryFunctionOffset: Int {
        return Int(self / 10)
    }

    var asRaspberryFunctionIndex: Int {
        return Int(self % 10)
    }
}


class RaspberryGPIOMem {
    init(baseAddr: UInt) {
        let mapper: MemMapper = MemMapper(devices: ["/dev/gpiomem", "/dev/mem"])

        let gpioAddress: UInt = baseAddr + RaspberryGPIOMem.gpioOffset
        guard let gpioPointer: UnsafeMutablePointer<UInt32> = mapper.map(address: gpioAddress) else { fatalError() }
        self.gpioBase = gpioPointer
        self.gpioLevels = gpioPointer.advanced(by: 13).rebindMemory(to: RaspberryGPIOLevels.self)
        self.gpioSet = gpioPointer.advanced(by: 7).rebindMemory(to: RaspberryGPIOSet.self)
        self.gpioClear = gpioPointer.advanced(by: 10).rebindMemory(to: RaspberryGPIOClear.self)

        self.gpioFunctionBase = gpioPointer.rebindMemory(to: RaspberryGPIOModeSet.self, capacity: 6)
        self.gpioPullup = gpioPointer.advanced(by: 37).rebindMemory(to: RaspberryGPIOPullup.self)
        self.gpioPullupClk = gpioPointer.advanced(by: 38).rebindMemory(to: RaspberryPullupClk.self)
    }

    // GPIOMemory
    static let gpioOffset: UInt = 0x200000
    private let gpioBase: UnsafeMutablePointer<UInt32>
    let gpioLevels: UnsafeMutablePointer<RaspberryGPIOLevels>
    let gpioSet: UnsafeMutablePointer<RaspberryGPIOSet>
    let gpioClear: UnsafeMutablePointer<RaspberryGPIOClear>

    // 0...5
    let gpioFunctionBase: UnsafeMutablePointer<RaspberryGPIOModeSet>
    let gpioPullup: UnsafeMutablePointer<RaspberryGPIOPullup>
    let gpioPullupClk: UnsafeMutablePointer<RaspberryPullupClk>
}

class RaspberrySecureGPIOMem {
    init(baseAddr: UInt) {
        let mapper: MemMapper = MemMapper(devices: ["/dev/mem"])

        let clockAddress: UInt = baseAddr + RaspberrySecureGPIOMem.clockOffset
        guard let clockPointer: UnsafeMutablePointer<UInt32> = mapper.map(address: clockAddress) else { fatalError() }
        self.clockBase = clockPointer
        self.clockCtrl = clockPointer.advanced(by: 40).rebindMemory(to: RaspberryClkCtrl.self)
        self.clockDivisor = clockPointer.advanced(by: 41).rebindMemory(to: RaspberryClkDivisor.self)

        let pwmAddress: UInt = baseAddr + RaspberrySecureGPIOMem.pwmOffset
        guard let pwmPointer: UnsafeMutablePointer<UInt32> = mapper.map(address: pwmAddress) else { fatalError() }
        self.pwmBase = pwmPointer
        self.pwmCtrl = pwmPointer.rebindMemory(to: RaspberryPWMCtrl.self)
        self.pwmRange0 = pwmPointer.advanced(by: 4)
        self.pwmData0 = pwmPointer.advanced(by: 5)
        self.pwmRange1 = pwmPointer.advanced(by: 8)
        self.pwmData1 = pwmPointer.advanced(by: 9)
    }

    // Clock Memory
    static let clockOffset: UInt = 0x101000
    private let clockBase: UnsafeMutablePointer<UInt32>
    let clockCtrl: UnsafeMutablePointer<RaspberryClkCtrl>
    let clockDivisor: UnsafeMutablePointer<RaspberryClkDivisor>

    // PWM Memory
    static let pwmOffset: UInt = 0x20C000
    private let pwmBase: UnsafeMutablePointer<UInt32>
    let pwmCtrl: UnsafeMutablePointer<RaspberryPWMCtrl>
    let pwmRange0: UnsafeMutablePointer<RaspberryPWMRange>
    let pwmData0: UnsafeMutablePointer<RaspberryPWMData>
    let pwmRange1: UnsafeMutablePointer<RaspberryPWMRange>
    let pwmData1: UnsafeMutablePointer<RaspberryPWMData>
}

fileprivate class MemMapper {
    private static let pageSize: Int = 1 << 12
    private var fdMemory: Int32 = -1

    init(devices: [String]) {
        for device in devices {
            fdMemory = open(device, O_RDWR | O_SYNC)
            if fdMemory > 0 { break }
        }

        guard fdMemory > 0 else {
            fatalError("Can't open /dev/mem, requires root.")
        }
    }

    deinit {
        if fdMemory != -1 {
            close(fdMemory)
        }
    }

    func map<T>(address: UInt) -> UnsafeMutablePointer<T>? {
        let mapResult = mmap(nil,
                            MemMapper.pageSize,
                            PROT_READ | PROT_WRITE,
                            MAP_SHARED,
                            fdMemory,
                            off_t(address))

        return mapResult?.bindMemory(to: T.self, capacity: 1)
    }
}

// MARK: GPIO Registers

typealias RaspberryGPIOSet    = PinSet
typealias RaspberryGPIOClear  = PinSet
typealias RaspberryGPIOLevels = PinSet

enum RaspberryGPIOMode: UInt32 {
    init(mode: PinMode) {
        switch mode {
        case .input: self = .input
        case .output: self = .output
        }
    }

    fileprivate init(checkedValue: UInt32) {
        self.init(rawValue: checkedValue)!
    }

    case input   = 0b000
    case output  = 0b001
    case alt0    = 0b100
    case alt1    = 0b101
    case alt2    = 0b110
    case alt3    = 0b111
    case alt4    = 0b011
    case alt5    = 0b010
}

struct RaspberryGPIOModeSet {
    public private(set) var rawValue: UInt32

    subscript(index: Int) -> RaspberryGPIOMode {
        get {
            guard index >= 0 && index < 10 else { fatalError() }

            let offset: UInt32 = UInt32(index * 3)
            let mask: UInt32 = 0x7

            return RaspberryGPIOMode(checkedValue: (self.rawValue >> offset) & mask)
        }
        set {
            guard index >= 0 && index < 10 else { fatalError() }

            let offset: UInt32 = UInt32(index * 3)
            let mask: UInt32 = 0x7 << offset

            self.rawValue &= ~mask
            self.rawValue |= (newValue.rawValue << offset) & mask
        }
    }
}

struct RaspberryGPIOPullup {
    // This could be an enum, but we also need a particular memory layout.
    public private(set) var rawValue: UInt32

    private init(_ value: UInt32) {
        self.rawValue = value
    }

    internal init(pullup: PinPullup) {
        switch pullup {
        case .none: self = .disabled
        case .down: self = .pullDown
        case .up:   self = .pullUp
        }
    }

    static let disabled = RaspberryGPIOPullup(0b00)
    static let pullDown = RaspberryGPIOPullup(0b01)
    static let pullUp   = RaspberryGPIOPullup(0b10)
}

typealias RaspberryPullupClk = PinSet

// MARK: Clock Registers

let RaspberryClkPasswd: UInt32 = 0x5A000000

struct RaspberryClkDivisor {
    public private(set) var rawValue: UInt32

    init(divi: UInt32, divf: UInt32 = 0) {
        self.rawValue = RaspberryClkPasswd
        self.divi = divi
        self.divf = divf
    }

    var divi: UInt32 {
        get { return fetch(offset: 12) }
        set { put(bits: newValue, atOffset: 12) }
    }

    var divf: UInt32 {
        get { return fetch(offset: 0) }
        set { put(bits: newValue, atOffset: 0) }
    }

    private mutating func put(bits: UInt32, atOffset offset: UInt32) {
        let mask: UInt32 = 0xFFF << offset
        rawValue &= ~mask
        rawValue |= RaspberryClkPasswd | mask & (bits << offset) // OR'ing the Password makes direct manipulation possible
    }

    private func fetch(offset: UInt32) -> UInt32 {
        let mask: UInt32 = 0xFFF
        return (rawValue >> offset) & mask
    }
}

struct RaspberryClkCtrl: OptionSet {
    let rawValue: UInt32

    var source: RaspberryClkCtrl {
        return RaspberryClkCtrl(rawValue: self.rawValue & 0x7)
    }

    static let password:         RaspberryClkCtrl = RaspberryClkCtrl(rawValue: RaspberryClkPasswd)

    static let enable:           RaspberryClkCtrl = RaspberryClkCtrl(rawValue: 1 << 4)
    static let kill:             RaspberryClkCtrl = RaspberryClkCtrl(rawValue: 1 << 5)

    static let sourceOscillator: RaspberryClkCtrl = RaspberryClkCtrl(rawValue: 1)
    static let sourcePLLA:       RaspberryClkCtrl = RaspberryClkCtrl(rawValue: 4)
    static let sourcePLLC:       RaspberryClkCtrl = RaspberryClkCtrl(rawValue: 5)
    static let sourcePLLD:       RaspberryClkCtrl = RaspberryClkCtrl(rawValue: 6)
    static let sourceHDMI:       RaspberryClkCtrl = RaspberryClkCtrl(rawValue: 7)
}

// MARK: PWM Registers

typealias RaspberryPWMRange = UInt32

typealias RaspberryPWMData = UInt32

struct RaspberryPWMCtrl: OptionSet {
    let rawValue: UInt32

    static let clearFifo:   RaspberryPWMCtrl = RaspberryPWMCtrl(rawValue: 1 << 6)   

    static let enable1:     RaspberryPWMCtrl = RaspberryPWMCtrl(rawValue: 1 << 0)   
    static let mode1:       RaspberryPWMCtrl = RaspberryPWMCtrl(rawValue: 1 << 1)   
    static let repeatLast1: RaspberryPWMCtrl = RaspberryPWMCtrl(rawValue: 1 << 2)   
    static let silence1:    RaspberryPWMCtrl = RaspberryPWMCtrl(rawValue: 1 << 3)   
    static let polarity1:   RaspberryPWMCtrl = RaspberryPWMCtrl(rawValue: 1 << 4)   
    static let useFifo1:    RaspberryPWMCtrl = RaspberryPWMCtrl(rawValue: 1 << 5)   
    static let enableMS1:   RaspberryPWMCtrl = RaspberryPWMCtrl(rawValue: 1 << 7)   

    static let enable2:     RaspberryPWMCtrl = RaspberryPWMCtrl(rawValue: 1 << 8)   
    static let mode2:       RaspberryPWMCtrl = RaspberryPWMCtrl(rawValue: 1 << 9)   
    static let repeatLast2: RaspberryPWMCtrl = RaspberryPWMCtrl(rawValue: 1 << 10)  
    static let silence2:    RaspberryPWMCtrl = RaspberryPWMCtrl(rawValue: 1 << 11)  
    static let polarity2:   RaspberryPWMCtrl = RaspberryPWMCtrl(rawValue: 1 << 12)  
    static let useFifo2:    RaspberryPWMCtrl = RaspberryPWMCtrl(rawValue: 1 << 13)  
    static let enableMS2:   RaspberryPWMCtrl = RaspberryPWMCtrl(rawValue: 1 << 15)
}

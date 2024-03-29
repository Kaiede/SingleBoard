# SingleBoard

[![Build Status](https://github.com/Kaiede/SingleBoard/workflows/CI/badge.svg)](https://github.com/Kaiede/SingleBoard/actions)
[![MIT license](http://img.shields.io/badge/license-MIT-brightgreen.svg)](http://opensource.org/licenses/MIT)

![Swift](https://img.shields.io/badge/Swift-5.1.5-brightgreen.svg?style=flat)
![Swift](https://img.shields.io/badge/Swift-5.5.2-brightgreen.svg?style=flat)

![SwiftPM](https://img.shields.io/badge/SwiftPM-✔-blue.svg?style=flat)

![Raspbian](https://img.shields.io/badge/OS-Raspbian-green.svg)

GPIO Library for Single Board Computers built in Swift.

## About the Project

This library is heavily based on [SwiftyGPIO](https://github.com/uraimo/SwiftyGPIO), and does share some code with it. The reason for rewriting is to try to improve the readability and maintainability of the code by strengthening type safety when interacting with hardware registers, and streamling the developer interaction. Doing it as a re-write was proving to be faster and easier to test than attempting to refactor it in-place.   

- [Supported Boards](#supported-boards)
- [Usage](#usage)
    - [GPIO](#gpio)
    - [I2C](#i2c)
    - [PWM](#pwm)
- [Built with SingleBoard](#built-with-singleboard)
    - [Device Libraries](#libraries)
    - [Projects](#projects)

## Supported Boards

* Raspberry Pi - GPIO, I²C, PWM

**Experimental**
* Rock 64 and Pine A64 - I²C  
* C.H.I.P. - I²C 

## Usage

#### GPIO

A simple example that toggles pin GPIO12/BCM12 on a Raspberry Pi on and off every second:

```Swift
let gpios = SingleBoard.raspberryPi.gpio

gpios[12].mode = .output
gpios[12].setPullup(.down)

while true {
    print("On!")
    gpios[12].value = true
    usleep(1_000_000)
    print("Off!")
    gpios[12].value = false
    usleep(1_000_000)
}
```

Things can go further, say you wanted to do this for 4 pins at the same time. SingleBoard supports the idea of pin sets to interact with a set of pins instead of just a single pin. The interface is different in subtle ways, but very similar: 

```Swift
let gpios = SingleBoard.raspberryPi.gpio

let pins: PinSet = [.p22, .p23, .p24, .p25]

gpios[pins].setMode(.output)
gpios[pins].setPullup(.down)

while true {
    print("On!")
    gpios[pins].value = true
    usleep(1_000_000)
    print("Off!")
    gpios[pins].value = false
    usleep(1_000_000)
}
```

If you just want a bit of type safety, you can also use pin sets of single pins, but it may be a bit slower in some cases, depending on which board you are targeting, and what operation you are doing. In the case of the Raspberry Pi, reading or writing many pins at once is perfectly fast. So is configuring pullups for many pins at once. However, using pin sets to set input/output modes is convenient, but slower than using pin indexes:

```Swift
gpios[.p12].value = true
gpios[[.p12, .p18]].setMode(.output)
gpios[[.p12, .p13, .p18, .p19]].setPullup(.down)
```

#### I2C

This is a brief example that writes to a device at address `0x40`, to write a `1` at offset `0x06`.

```Swift
// Get a connection for a device with address 0x40 on the board's primary bus
print(SingleBoard.raspberryPi.i2cMainBus.busId)
let i2cDevice = SingleBoard.raspberryPi.i2cMainBus[0x40]

i2cDevice.writeByte(to: 0x06, value: 1)
```

A board's main bus is considered to be the one that is primarily for use by those developing on the single board computer, and not for the system's use. 

On the Raspberry Pi, bus 0 is used by the system for a handful of things including identifying HATs. Bus 1 is exposed on pins 3 & 5 for use by tinkerers, and so bus 1 is considered the main bus. On the Rock 64, it's the opposite. Bus 0 is exposed on pins 3 & 5, while bus 1 is used for HATs and system devices. The Pine A64 is like the Raspberry Pi. By exposing the main bus as a property, it makes it a bit easier to write code that can handle multiple similar boards. 

The full set of basic read/write functionality is the following:

```Swift
    var reachable: Bool { get }

    //
    // I2C API
    //
    func readByte() -> UInt8
    func readWord() -> UInt16
    func readData(length: Int) -> Data
    func decode<T: I2CReadable>() -> T

    func writeByte(value: UInt8)
    func writeWord(value: UInt16)
    func writeData(value: Data)
    func encode<T: I2CWritable>(value: T)

    //
    // SMBus
    //
    func readByte(command: UInt8) -> UInt8
    func readWord(command: UInt8) -> UInt16
    func readData(command: UInt8) -> Data
    func decode<T: I2CReadable>(command: UInt8) -> T

    func writeQuick()
    func writeByte(command: UInt8, value: UInt8)
    func writeWord(command: UInt8, value: UInt16)
    func writeData(command: UInt8, value: Data)
    func encode<T: I2CWritable>(command: UInt8, value: T)
```
    
But in addition to this, there is also support for handling types that conform to `RawRepresentable` and `OptionSet` automatically. For example, any RawRepresentable that is backed by a UInt8 can be used to read or write bytes and words:

```Swift
enum MyDeviceRegisters: UInt8, RawRepresentable { /* ... */ }

i2cDevice.writeByte(command: MyDeviceRegisters.control, value: 0x48)
```

Taken a step further, you can also use `RawRepresentable` and `OptionSet` as the bytes or words themselves if they are backed by `UInt8` or `UInt16`:

```Swift
enum MyDeviceRegisters: UInt8, RawRepresentable { /* ... */ }
struct MyControlRegister: OptionSet {
	let rawValue: UInt16

	/* ... */
}

let controlValue: MyControlRegister = [.sleep, .reset]
i2cDevice.write(command: MyDeviceRegisters.control, value: controlValue)
```

Reading works the same way.

For more complex types, there's protocols that you can implement to enable calling `encode` and `decode` on the endpoint with your own types. These leverage `Data` for storing the buffers, but make it possible to keep code a little cleaner.

```Swift
protocol I2CReadable { /* ... */ }
protocol I2CWritable { /* ... */ }
protocol I2CReadWritable { /* ... */ }
```

The idea here is to make it a bit easier to use more restrictive types to represent the values to be read and written when interacting with the I2C device. These techniques are demonstrated in the [PCA9685](https://github.com/Kaiede/PCA9685) and [MCP4725](https://github.com/Kaiede/MCP4725) libraries. 

#### PWM

A very simple example here, telling a Raspberry Pi to output on channel 0, using both of its output pins:

```Swift
let pwmChannel = SingleBoard.raspberryPi.pwm[0]

pwmChannel.enable(pins: pwmChannel.pins)
pwmChannel.start(period: 1_000_000 /* nanoseconds */, dutyCycle: 0.5)
```

Much like GPIOs, enabling the output on pins can use a pin index, or a pin set:

```Swift
let pwmChannel = SingleBoard.raspberryPi.pwm[0]

pwmChannel.enable(pin: 12)
pwmChannel.enable(pins: .p18)
pwmChannel.enable(pins: [.p12, .p18])
```

## Built with SingleBoard

#### Included Libraries

* PCA9685 - A library for the PCA9685 I2C PWM/Servo controller.
* MCP4725 - A library for the MCP4725 I2C DAC chip. 

#### Projects

* [RPiLight](https://github.com/Kaiede/RPiLight) - An aquarium light controller. 

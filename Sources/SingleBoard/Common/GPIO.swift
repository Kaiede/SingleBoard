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

public enum PinPullup {
	case none
	case up
	case down
}

public enum PinMode {
	case input
	case output
}

public typealias PinIndex = UInt32

public struct PinSet: OptionSet {
	public let rawValue: UInt32

	public init?(index: PinIndex) {
		guard index < 32 else { return nil }
		self.rawValue = 1 << index
	}

	public init(rawValue: UInt32) {
		self.rawValue = rawValue
	}

	public static let p0:  PinSet = PinSet(rawValue: 1 << 0)
	public static let p1:  PinSet = PinSet(rawValue: 1 << 1)
	public static let p2:  PinSet = PinSet(rawValue: 1 << 2)
	public static let p3:  PinSet = PinSet(rawValue: 1 << 3)
	public static let p4:  PinSet = PinSet(rawValue: 1 << 4)
	public static let p5:  PinSet = PinSet(rawValue: 1 << 5)
	public static let p6:  PinSet = PinSet(rawValue: 1 << 6)
	public static let p7:  PinSet = PinSet(rawValue: 1 << 7)
	public static let p8:  PinSet = PinSet(rawValue: 1 << 8)
	public static let p9:  PinSet = PinSet(rawValue: 1 << 9)
	public static let p10: PinSet = PinSet(rawValue: 1 << 10)
	public static let p11: PinSet = PinSet(rawValue: 1 << 11)
	public static let p12: PinSet = PinSet(rawValue: 1 << 12)
	public static let p13: PinSet = PinSet(rawValue: 1 << 13)
	public static let p14: PinSet = PinSet(rawValue: 1 << 14)
	public static let p15: PinSet = PinSet(rawValue: 1 << 15)
	public static let p16: PinSet = PinSet(rawValue: 1 << 16)
	public static let p17: PinSet = PinSet(rawValue: 1 << 17)
	public static let p18: PinSet = PinSet(rawValue: 1 << 18)
	public static let p19: PinSet = PinSet(rawValue: 1 << 19)
	public static let p20: PinSet = PinSet(rawValue: 1 << 20)
	public static let p21: PinSet = PinSet(rawValue: 1 << 21)
	public static let p22: PinSet = PinSet(rawValue: 1 << 22)
	public static let p23: PinSet = PinSet(rawValue: 1 << 23)
	public static let p24: PinSet = PinSet(rawValue: 1 << 24)
	public static let p25: PinSet = PinSet(rawValue: 1 << 25)
	public static let p26: PinSet = PinSet(rawValue: 1 << 26)
	public static let p27: PinSet = PinSet(rawValue: 1 << 27)
	public static let p28: PinSet = PinSet(rawValue: 1 << 28)
	public static let p29: PinSet = PinSet(rawValue: 1 << 29)
	public static let p30: PinSet = PinSet(rawValue: 1 << 30)
	public static let p31: PinSet = PinSet(rawValue: 1 << 31)
}

public extension PinSet {
    func indexes() -> AnySequence<PinIndex> {
        var remainingBits = rawValue
        var currentIndex: PinIndex = 0
        let bitMask: RawValue = 1
        return AnySequence {
            return AnyIterator {
                while remainingBits != 0 {
                    if remainingBits & bitMask != 0 {
                        remainingBits = remainingBits & ~bitMask
                        return currentIndex
                    }
                    currentIndex += 1
                    remainingBits = remainingBits >> 1
                }
                return nil
            }
        }
    }
}


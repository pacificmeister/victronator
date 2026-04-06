import XCTest
@testable import Victronator

final class SmartSolarParserTests: XCTestCase {

    func testParseValidPayload() {
        // Build a test payload with known values:
        // chargeState=3 (Bulk), chargerError=0, batteryVoltage=1380 (13.80V),
        // batteryChargingCurrent=52 (5.2A), yieldToday=340 (3400Wh),
        // solarPower=280 (280W), externalDeviceLoad=15 (1.5A)
        var bits = [UInt8](repeating: 0, count: 16)

        func writeBits(_ value: UInt32, count: Int, at offset: inout Int) {
            for i in 0..<count {
                let bit = (value >> i) & 1
                let byteIdx = offset / 8
                let bitIdx = offset % 8
                if bit == 1 {
                    bits[byteIdx] |= UInt8(1 << bitIdx)
                }
                offset += 1
            }
        }

        var offset = 0
        writeBits(3, count: 8, at: &offset)            // chargeState = Bulk
        writeBits(0, count: 8, at: &offset)             // chargerError = 0
        writeBits(UInt32(bitPattern: 1380), count: 16, at: &offset)  // batteryVoltage (13.80V)
        writeBits(UInt32(bitPattern: 52), count: 16, at: &offset)    // batteryChargingCurrent (5.2A)
        writeBits(340, count: 16, at: &offset)          // yieldToday (3400Wh)
        writeBits(280, count: 16, at: &offset)          // solarPower (280W)
        writeBits(15, count: 9, at: &offset)            // externalDeviceLoad (1.5A)

        let data = Data(bits.prefix(12))
        let reading = SmartSolarParser.parse(data: data)

        XCTAssertNotNil(reading)
        XCTAssertEqual(reading?.chargeState, 3)
        XCTAssertEqual(reading?.chargerError, 0)
        XCTAssertEqual(reading?.batteryVoltage, 13.80, accuracy: 0.01)
        XCTAssertEqual(reading?.batteryChargingCurrent, 5.2, accuracy: 0.1)
        XCTAssertEqual(reading?.yieldToday, 3400.0, accuracy: 0.1)
        XCTAssertEqual(reading?.solarPower, 280)
        XCTAssertEqual(reading?.externalDeviceLoad, 1.5, accuracy: 0.1)
        XCTAssertEqual(reading?.chargeStateDescription, "Bulk")
    }

    func testNullSolarPower() {
        var bits = [UInt8](repeating: 0, count: 16)

        func writeBits(_ value: UInt32, count: Int, at offset: inout Int) {
            for i in 0..<count {
                let bit = (value >> i) & 1
                let byteIdx = offset / 8
                let bitIdx = offset % 8
                if bit == 1 {
                    bits[byteIdx] |= UInt8(1 << bitIdx)
                }
                offset += 1
            }
        }

        var offset = 0
        writeBits(0, count: 8, at: &offset)              // chargeState
        writeBits(0, count: 8, at: &offset)               // chargerError
        writeBits(0, count: 16, at: &offset)              // batteryVoltage
        writeBits(0, count: 16, at: &offset)              // batteryChargingCurrent
        writeBits(0, count: 16, at: &offset)              // yieldToday
        writeBits(0xFFFF, count: 16, at: &offset)         // solarPower = null sentinel
        writeBits(0, count: 9, at: &offset)               // externalDeviceLoad

        let data = Data(bits.prefix(12))
        let reading = SmartSolarParser.parse(data: data)

        XCTAssertNotNil(reading)
        XCTAssertNil(reading?.solarPower)
    }

    func testTooShortData() {
        let data = Data([0x00, 0x01, 0x02])
        XCTAssertNil(SmartSolarParser.parse(data: data))
    }
}

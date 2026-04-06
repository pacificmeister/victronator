import XCTest
@testable import Victronator

final class SmartShuntParserTests: XCTestCase {

    func testParseValidPayload() {
        // Construct a test payload with known values:
        // timeToGo=120 (0x0078), batteryVoltage=1254 (0x04E6 = 12.54V),
        // alarmReason=0, auxInput=0, auxInputType=3 (disabled),
        // batteryCurrent=-5230 (= -5.230A), consumedAh=150 (= -15.0Ah),
        // stateOfCharge=850 (= 85.0%)
        //
        // We build this as a bit stream. For simplicity, use BitWriter approach:
        var bits = [UInt8](repeating: 0, count: 16)

        // Helper to write bits LSB-first
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
        writeBits(120, count: 16, at: &offset)        // timeToGo = 120 minutes
        writeBits(UInt32(bitPattern: 1254), count: 16, at: &offset)  // batteryVoltage = 1254 (12.54V)
        writeBits(0, count: 16, at: &offset)           // alarmReason = 0
        writeBits(0, count: 16, at: &offset)           // auxInput = 0
        writeBits(3, count: 2, at: &offset)            // auxInputType = 3 (disabled)

        // batteryCurrent = -5230 as signed 22-bit: 2^22 - 5230 = 4189042 = 0x3FEB72
        let signedCurrent = UInt32(bitPattern: -5230) & 0x3FFFFF
        writeBits(signedCurrent, count: 22, at: &offset)

        writeBits(150, count: 20, at: &offset)         // consumedAh = 150 (= -15.0Ah)
        writeBits(850, count: 10, at: &offset)         // stateOfCharge = 850 (85.0%)

        let data = Data(bits.prefix(15))
        let reading = SmartShuntParser.parse(data: data)

        XCTAssertNotNil(reading)
        XCTAssertEqual(reading?.timeToGo, 120)
        XCTAssertEqual(reading?.batteryVoltage, 12.54, accuracy: 0.01)
        XCTAssertEqual(reading?.batteryCurrent, -5.23, accuracy: 0.001)
        XCTAssertEqual(reading?.consumedAh, -15.0, accuracy: 0.1)
        XCTAssertEqual(reading?.stateOfCharge, 85.0, accuracy: 0.1)
        XCTAssertEqual(reading?.auxInputType, 3)
    }

    func testNullValues() {
        // Set all fields to their null sentinels
        var bits = [UInt8](repeating: 0xFF, count: 16)

        // auxInputType is only 2 bits, sits at bit offset 82-83
        // Set stateOfCharge null = 0x3FF (10 bits all 1s) - already all 1s

        let data = Data(bits.prefix(15))
        let reading = SmartShuntParser.parse(data: data)

        XCTAssertNotNil(reading)
        XCTAssertNil(reading?.timeToGo)
        // batteryVoltage: raw signed 16-bit all 1s = -1, check against 0x7FFF
        // With all 0xFF bytes, signed 16 = -1, unsigned = 0xFFFF != 0x7FFF, so not null
        // This is expected - null check uses the unsigned representation
        XCTAssertNil(reading?.stateOfCharge) // 0x3FF = null sentinel
    }

    func testBatteryPowerCalculation() {
        // Create a reading with known voltage and current
        let reading = SmartShuntReading(
            timeToGo: nil,
            batteryVoltage: 12.5,
            alarmReason: 0,
            auxInput: 0,
            auxInputType: 3,
            batteryCurrent: -10.0,
            consumedAh: nil,
            stateOfCharge: 50.0
        )

        XCTAssertEqual(reading.batteryPowerWatts, -125.0, accuracy: 0.1)
    }

    func testTooShortData() {
        let data = Data([0x00, 0x01])
        XCTAssertNil(SmartShuntParser.parse(data: data))
    }
}

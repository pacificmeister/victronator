import Foundation

/// Parses decrypted Inverter BLE payload.
/// Record type 0x03, total 82 bits.
struct InverterParser {
    static func parse(data: Data) -> InverterReading? {
        guard data.count >= 11 else { return nil } // 82 bits = ~11 bytes

        var reader = BitReader(data: data)

        let rawDeviceState = reader.readUnsigned(bits: 8)
        let rawAlarmReason = reader.readUnsigned(bits: 16)
        let rawBatteryVoltage = reader.readSigned(bits: 16)
        let rawAcApparentPower = reader.readUnsigned(bits: 16)
        let rawAcVoltage = reader.readUnsigned(bits: 15)
        let rawAcCurrent = reader.readUnsigned(bits: 11)

        let batteryVoltage: Double? = UInt32(bitPattern: rawBatteryVoltage) != 0x7FFF
            ? Double(rawBatteryVoltage) / 100.0 : nil

        let acApparentPower: UInt16? = rawAcApparentPower != 0xFFFF
            ? UInt16(rawAcApparentPower) : nil

        let acVoltage: Double? = rawAcVoltage != 0x7FFF
            ? Double(rawAcVoltage) / 100.0 : nil

        let acCurrent: Double? = rawAcCurrent != 0x7FF
            ? Double(rawAcCurrent) / 10.0 : nil

        return InverterReading(
            deviceState: UInt8(rawDeviceState),
            alarmReason: UInt16(rawAlarmReason),
            batteryVoltage: batteryVoltage,
            acApparentPower: acApparentPower,
            acVoltage: acVoltage,
            acCurrent: acCurrent
        )
    }
}

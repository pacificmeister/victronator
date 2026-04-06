import Foundation

/// Parses decrypted SmartShunt (Battery Monitor) BLE payload.
/// Record type 0x02, total 118 bits.
struct SmartShuntParser {
    static func parse(data: Data) -> SmartShuntReading? {
        guard data.count >= 15 else { return nil } // 118 bits = ~15 bytes

        var reader = BitReader(data: data)

        let rawTimeToGo = reader.readUnsigned(bits: 16)
        let rawBatteryVoltage = reader.readSigned(bits: 16)
        let rawAlarmReason = reader.readUnsigned(bits: 16)
        let rawAuxInput = reader.readUnsigned(bits: 16)
        let rawAuxInputType = reader.readUnsigned(bits: 2)
        let rawBatteryCurrent = reader.readSigned(bits: 22)
        let rawConsumedAh = reader.readUnsigned(bits: 20)
        let rawSOC = reader.readUnsigned(bits: 10)

        let timeToGo: UInt16? = rawTimeToGo != VictronConstants.SmartShuntNull.timeToGo
            ? UInt16(rawTimeToGo) : nil

        let batteryVoltage: Double? = UInt32(bitPattern: rawBatteryVoltage) != VictronConstants.SmartShuntNull.batteryVoltage
            ? Double(rawBatteryVoltage) / 100.0 : nil

        let batteryCurrent: Double? = UInt32(bitPattern: rawBatteryCurrent) != VictronConstants.SmartShuntNull.batteryCurrent
            ? Double(rawBatteryCurrent) / 1000.0 : nil

        let consumedAh: Double? = rawConsumedAh != VictronConstants.SmartShuntNull.consumedAh
            ? Double(rawConsumedAh) / -10.0 : nil

        let stateOfCharge: Double? = rawSOC != VictronConstants.SmartShuntNull.stateOfCharge
            ? Double(rawSOC) / 10.0 : nil

        return SmartShuntReading(
            timeToGo: timeToGo,
            batteryVoltage: batteryVoltage,
            alarmReason: UInt16(rawAlarmReason),
            auxInput: rawAuxInput,
            auxInputType: UInt8(rawAuxInputType),
            batteryCurrent: batteryCurrent,
            consumedAh: consumedAh,
            stateOfCharge: stateOfCharge
        )
    }
}

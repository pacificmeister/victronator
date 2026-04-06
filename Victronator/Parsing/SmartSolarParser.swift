import Foundation

/// Parses decrypted SmartSolar MPPT BLE payload.
/// Record type 0x01, total 89 bits.
struct SmartSolarParser {
    static func parse(data: Data) -> SmartSolarReading? {
        guard data.count >= 12 else { return nil } // 89 bits = ~12 bytes

        var reader = BitReader(data: data)

        let rawChargeState = reader.readUnsigned(bits: 8)
        let rawChargerError = reader.readUnsigned(bits: 8)
        let rawBatteryVoltage = reader.readSigned(bits: 16)
        let rawBatteryChargingCurrent = reader.readSigned(bits: 16)
        let rawYieldToday = reader.readUnsigned(bits: 16)
        let rawSolarPower = reader.readUnsigned(bits: 16)
        let rawExternalDeviceLoad = reader.readUnsigned(bits: 9)

        let batteryVoltage: Double? = UInt32(bitPattern: rawBatteryVoltage) != VictronConstants.SmartSolarNull.batteryVoltage
            ? Double(rawBatteryVoltage) / 100.0 : nil

        let batteryChargingCurrent: Double? = UInt32(bitPattern: rawBatteryChargingCurrent) != VictronConstants.SmartSolarNull.batteryChargingCurrent
            ? Double(rawBatteryChargingCurrent) / 10.0 : nil

        let yieldToday: Double? = rawYieldToday != VictronConstants.SmartSolarNull.yieldToday
            ? Double(rawYieldToday) * 10.0 : nil

        let solarPower: UInt16? = rawSolarPower != VictronConstants.SmartSolarNull.solarPower
            ? UInt16(rawSolarPower) : nil

        let externalDeviceLoad: Double? = rawExternalDeviceLoad != VictronConstants.SmartSolarNull.externalDeviceLoad
            ? Double(rawExternalDeviceLoad) / 10.0 : nil

        return SmartSolarReading(
            chargeState: UInt8(rawChargeState),
            chargerError: UInt8(rawChargerError),
            batteryVoltage: batteryVoltage,
            batteryChargingCurrent: batteryChargingCurrent,
            yieldToday: yieldToday,
            solarPower: solarPower,
            externalDeviceLoad: externalDeviceLoad
        )
    }
}

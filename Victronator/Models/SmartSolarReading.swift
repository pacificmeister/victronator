import Foundation

/// Decoded data from a Victron SmartSolar MPPT BLE advertisement.
struct SmartSolarReading {
    let chargeState: UInt8              // See VictronConstants.ChargeState
    let chargerError: UInt8             // Error code
    let batteryVoltage: Double?         // Volts
    let batteryChargingCurrent: Double? // Amps
    let yieldToday: Double?             // Wh produced today
    let solarPower: UInt16?             // Watts
    let externalDeviceLoad: Double?     // Amps

    /// Charge state as a human-readable string.
    var chargeStateDescription: String {
        VictronConstants.ChargeState(rawValue: chargeState)?.description ?? "Unknown (\(chargeState))"
    }
}

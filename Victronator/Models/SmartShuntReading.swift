import Foundation

/// Decoded data from a Victron SmartShunt (Battery Monitor) BLE advertisement.
struct SmartShuntReading {
    let timeToGo: UInt16?       // Minutes remaining, nil if unavailable
    let batteryVoltage: Double?  // Volts
    let alarmReason: UInt16      // Alarm flags
    let auxInput: UInt32         // Raw aux input value
    let auxInputType: UInt8      // 0=starter V, 1=midpoint V, 2=temperature, 3=disabled
    let batteryCurrent: Double?  // Amps (negative = discharging)
    let consumedAh: Double?      // Ah consumed (negative value)
    let stateOfCharge: Double?   // Percentage (0-100)

    /// Battery power in watts. Positive = charging, negative = discharging.
    var batteryPowerWatts: Double? {
        guard let v = batteryVoltage, let a = batteryCurrent else { return nil }
        return v * a
    }

    /// Aux input interpreted as temperature in Celsius (when auxInputType == 2).
    var temperatureCelsius: Double? {
        guard auxInputType == 2 else { return nil }
        return Double(auxInput) / 100.0 - 273.15
    }
}

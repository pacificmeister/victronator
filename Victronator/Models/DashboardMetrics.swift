import Foundation

/// Aggregated metrics for the main dashboard, computed from device readings.
struct DashboardMetrics {
    var stateOfCharge: Double?      // % from SmartShunt
    var solarPowerWatts: Double?    // W from SmartSolar
    var batteryPowerWatts: Double?  // W from SmartShunt (V*A, positive=charging)
    var chargeState: String?        // From SmartSolar (e.g., "Bulk", "Float")
    var batteryVoltage: Double?     // V from SmartShunt
    var yieldToday: Double?         // Wh from SmartSolar

    /// Consumer power = solar - battery charging power.
    /// When battery is charging (positive), consumers get the remainder.
    /// When battery is discharging (negative), consumers get solar + battery discharge.
    var consumerPowerWatts: Double? {
        guard let solar = solarPowerWatts, let battery = batteryPowerWatts else { return nil }
        return solar - battery
    }

    static let empty = DashboardMetrics()
}

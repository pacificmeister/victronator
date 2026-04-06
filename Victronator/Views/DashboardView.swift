import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var deviceManager: DeviceManager

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    StatusBannerView()

                    LazyVGrid(columns: columns, spacing: 16) {
                        // State of Charge
                        MetricCardView(
                            title: "State of Charge",
                            value: formatSOC(deviceManager.metrics.stateOfCharge),
                            unit: "%",
                            icon: "battery.75percent",
                            color: socColor(deviceManager.metrics.stateOfCharge),
                            subtitle: formatVoltage(deviceManager.metrics.batteryVoltage)
                        )

                        // Solar Power
                        MetricCardView(
                            title: "Solar Power",
                            value: formatPower(deviceManager.metrics.solarPowerWatts),
                            unit: "W",
                            icon: "sun.max.fill",
                            color: .orange,
                            subtitle: deviceManager.metrics.chargeState
                        )

                        // Consumer Power
                        MetricCardView(
                            title: "Consumers",
                            value: formatPower(deviceManager.metrics.consumerPowerWatts),
                            unit: "W",
                            icon: "powerplug.fill",
                            color: .purple,
                            subtitle: formatYield(deviceManager.metrics.yieldToday)
                        )

                        // Battery Power
                        MetricCardView(
                            title: "Battery",
                            value: formatBatteryPower(deviceManager.metrics.batteryPowerWatts),
                            unit: "W",
                            icon: batteryIcon(deviceManager.metrics.batteryPowerWatts),
                            color: batteryColor(deviceManager.metrics.batteryPowerWatts),
                            subtitle: batteryDirection(deviceManager.metrics.batteryPowerWatts)
                        )
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Victronator")
        }
    }

    // MARK: - Formatters

    private func formatSOC(_ soc: Double?) -> String {
        guard let soc = soc else { return "--" }
        return String(format: "%.0f", soc)
    }

    private func formatPower(_ watts: Double?) -> String {
        guard let watts = watts else { return "--" }
        return String(format: "%.0f", abs(watts))
    }

    private func formatBatteryPower(_ watts: Double?) -> String {
        guard let watts = watts else { return "--" }
        let prefix = watts >= 0 ? "+" : "-"
        return "\(prefix)\(String(format: "%.0f", abs(watts)))"
    }

    private func formatVoltage(_ volts: Double?) -> String {
        guard let volts = volts else { return nil ?? "" }
        return String(format: "%.1f V", volts)
    }

    private func formatYield(_ wh: Double?) -> String {
        guard let wh = wh else { return nil ?? "" }
        if wh >= 1000 {
            return String(format: "%.1f kWh today", wh / 1000)
        }
        return String(format: "%.0f Wh today", wh)
    }

    private func socColor(_ soc: Double?) -> Color {
        guard let soc = soc else { return .gray }
        if soc >= 80 { return .green }
        if soc >= 50 { return .yellow }
        if soc >= 20 { return .orange }
        return .red
    }

    private func batteryIcon(_ watts: Double?) -> String {
        guard let watts = watts else { return "battery.50percent" }
        return watts >= 0 ? "battery.100percent.bolt" : "battery.25percent"
    }

    private func batteryColor(_ watts: Double?) -> Color {
        guard let watts = watts else { return .gray }
        return watts >= 0 ? .green : .red
    }

    private func batteryDirection(_ watts: Double?) -> String {
        guard let watts = watts else { return "" }
        return watts >= 0 ? "Charging" : "Discharging"
    }
}

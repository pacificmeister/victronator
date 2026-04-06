import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var deviceManager: DeviceManager

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    StatusBannerView()

                    // Energy Flow Diagram
                    EnergyFlowView(
                        metrics: deviceManager.metrics,
                        isShoreDetected: deviceManager.dataHistory.isShoreDetected
                    )
                    .padding(.horizontal)

                    // Key Metrics Grid
                    LazyVGrid(columns: columns, spacing: 12) {
                        MetricCardView(
                            title: "State of Charge",
                            value: formatSOC(deviceManager.metrics.stateOfCharge),
                            unit: "%",
                            icon: "battery.75percent",
                            color: socColor(deviceManager.metrics.stateOfCharge),
                            subtitle: formatVoltage(deviceManager.metrics.batteryVoltage)
                        )

                        MetricCardView(
                            title: "Solar",
                            value: formatPower(deviceManager.metrics.solarPowerWatts),
                            unit: "W",
                            icon: "sun.max.fill",
                            color: .orange,
                            subtitle: deviceManager.metrics.chargeState
                        )

                        MetricCardView(
                            title: "Battery",
                            value: formatBatteryPower(deviceManager.metrics.batteryPowerWatts),
                            unit: "W",
                            icon: batteryIcon(deviceManager.metrics.batteryPowerWatts),
                            color: batteryColor(deviceManager.metrics.batteryPowerWatts),
                            subtitle: batteryDirection(deviceManager.metrics.batteryPowerWatts)
                        )

                        MetricCardView(
                            title: deviceManager.dataHistory.isShoreDetected ? "Loads + Shore" : "Consumers",
                            value: formatPower(deviceManager.metrics.consumerPowerWatts ?? deviceManager.metrics.inverterPowerVA),
                            unit: "W",
                            icon: deviceManager.dataHistory.isShoreDetected ? "powerplug.fill" : "house.fill",
                            color: deviceManager.dataHistory.isShoreDetected ? .cyan : .purple,
                            subtitle: formatYield(deviceManager.metrics.yieldToday)
                        )

                        // Inverter card (only when detected)
                        if deviceManager.metrics.inverterPowerVA != nil {
                            MetricCardView(
                                title: "Inverter",
                                value: formatPower(deviceManager.metrics.inverterPowerVA),
                                unit: "VA",
                                icon: "bolt.circle.fill",
                                color: .blue,
                                subtitle: formatACInfo(deviceManager.metrics)
                            )
                        }
                    }
                    .padding(.horizontal)

                    // 24-Hour History Chart
                    if !deviceManager.dataHistory.points.isEmpty {
                        ChartView(points: deviceManager.dataHistory.points)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 20)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Victronator")
        }
        .navigationViewStyle(.stack)
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
        guard let volts = volts else { return "" }
        return String(format: "%.1f V", volts)
    }

    private func formatACInfo(_ m: DashboardMetrics) -> String {
        var parts: [String] = []
        if let v = m.acVoltage { parts.append(String(format: "%.0f V AC", v)) }
        if let state = m.inverterState { parts.append(state) }
        return parts.joined(separator: " · ")
    }

    private func formatYield(_ wh: Double?) -> String {
        guard let wh = wh else { return "" }
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

import SwiftUI

/// Animated energy flow diagram showing power flowing between
/// Solar -> Battery -> Consumers, with optional shore power detection.
struct EnergyFlowView: View {
    let metrics: DashboardMetrics
    let isShoreDetected: Bool

    @State private var flowPhase: CGFloat = 0

    private let nodeSize: CGFloat = 56
    private let iconSize: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h: CGFloat = 180

            let solarPos = CGPoint(x: w / 2, y: 20)
            let batteryPos = CGPoint(x: 60, y: h / 2 + 10)
            let consumerPos = CGPoint(x: w - 60, y: h / 2 + 10)
            let shorePos = CGPoint(x: w / 2, y: h - 10)

            ZStack {
                // Flow lines with animated dots
                // Solar -> Battery (when solar is producing and battery charging)
                if solarToBattery > 0 {
                    FlowLine(from: solarPos, to: batteryPos, watts: solarToBattery,
                             color: .orange, phase: flowPhase, speed: flowSpeed(solarToBattery))
                }

                // Solar -> Consumer
                if solarToConsumer > 0 {
                    FlowLine(from: solarPos, to: consumerPos, watts: solarToConsumer,
                             color: .orange, phase: flowPhase, speed: flowSpeed(solarToConsumer))
                }

                // Battery -> Consumer (discharging)
                if batteryToConsumer > 0 {
                    FlowLine(from: batteryPos, to: consumerPos, watts: batteryToConsumer,
                             color: .green, phase: flowPhase, speed: flowSpeed(batteryToConsumer))
                }

                // Shore -> Battery (charging from shore)
                if isShoreDetected {
                    FlowLine(from: shorePos, to: batteryPos, watts: shorePower,
                             color: .cyan, phase: flowPhase, speed: flowSpeed(shorePower))
                    FlowLine(from: shorePos, to: consumerPos, watts: shorePower * 0.3,
                             color: .cyan, phase: flowPhase, speed: flowSpeed(shorePower * 0.3))
                }

                // Nodes
                EnergyNode(icon: "sun.max.fill", label: "Solar",
                           value: formatW(metrics.solarPowerWatts),
                           color: .orange, size: nodeSize)
                    .position(solarPos)

                EnergyNode(icon: "battery.75percent", label: "Battery",
                           value: formatSOC(metrics.stateOfCharge),
                           color: .green, size: nodeSize)
                    .position(batteryPos)

                EnergyNode(icon: "house.fill", label: "Loads",
                           value: formatW(estimatedConsumer),
                           color: .purple, size: nodeSize)
                    .position(consumerPos)

                if isShoreDetected {
                    EnergyNode(icon: "powerplug.fill", label: "Shore",
                               value: formatW(shorePower),
                               color: .cyan, size: nodeSize)
                        .position(shorePos)
                }
            }
            .frame(height: h)
        }
        .frame(height: 180)
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                flowPhase = 1
            }
        }
    }

    // MARK: - Power Flow Calculations

    private var solar: Double { metrics.solarPowerWatts ?? 0 }
    private var battery: Double { metrics.batteryPowerWatts ?? 0 } // positive = charging
    private var estimatedConsumer: Double? { metrics.consumerPowerWatts ?? metrics.inverterPowerVA }

    private var solarToBattery: Double {
        guard solar > 0, battery > 0 else { return 0 }
        return min(solar, battery)
    }

    private var solarToConsumer: Double {
        guard solar > 0 else { return 0 }
        let consumer = estimatedConsumer ?? 0
        return min(solar, consumer)
    }

    private var batteryToConsumer: Double {
        guard battery < 0 else { return 0 } // negative = discharging
        return abs(battery)
    }

    private var shorePower: Double {
        guard isShoreDetected, battery > 0 else { return 0 }
        let consumer = estimatedConsumer ?? 0
        return max(0, battery + consumer - solar)
    }

    private func flowSpeed(_ watts: Double) -> CGFloat {
        CGFloat(min(max(watts / 500, 0.3), 2.0))
    }

    private func formatW(_ watts: Double?) -> String {
        guard let w = watts else { return "--" }
        return "\(Int(abs(w)))W"
    }

    private func formatSOC(_ soc: Double?) -> String {
        guard let s = soc else { return "--" }
        return "\(Int(s))%"
    }
}

// MARK: - Flow Line with Animated Dots

struct FlowLine: View {
    let from: CGPoint
    let to: CGPoint
    let watts: Double
    let color: Color
    let phase: CGFloat
    let speed: CGFloat

    var body: some View {
        ZStack {
            // Static line
            Path { path in
                path.move(to: from)
                path.addLine(to: to)
            }
            .stroke(color.opacity(0.2), lineWidth: 2)

            // Animated dots
            ForEach(0..<3, id: \.self) { i in
                let offset = CGFloat(i) / 3.0
                let t = (phase * speed + offset).truncatingRemainder(dividingBy: 1.0)
                Circle()
                    .fill(color)
                    .frame(width: dotSize, height: dotSize)
                    .shadow(color: color, radius: 4)
                    .position(
                        x: from.x + (to.x - from.x) * t,
                        y: from.y + (to.y - from.y) * t
                    )
            }

            // Watt label at midpoint
            Text("\(Int(watts))W")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(color.opacity(0.8))
                .position(
                    x: (from.x + to.x) / 2 + labelOffset.x,
                    y: (from.y + to.y) / 2 + labelOffset.y
                )
        }
    }

    private var dotSize: CGFloat {
        CGFloat(min(max(watts / 200, 4), 10))
    }

    private var labelOffset: CGPoint {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0 else { return .zero }
        // Perpendicular offset
        return CGPoint(x: -dy / len * 12, y: dx / len * 12)
    }
}

// MARK: - Energy Node

struct EnergyNode: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    let size: CGFloat

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: size, height: size)
                Circle()
                    .stroke(color.opacity(0.4), lineWidth: 1.5)
                    .frame(width: size, height: size)
                Image(systemName: icon)
                    .font(.system(size: size * 0.35))
                    .foregroundColor(color)
            }
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}

import SwiftUI

/// Energy flow diagram with 4 boxes in a 2x2 grid:
///   [Solar]      [Generator]
///   [Battery]    [Loads]
/// Arrows between boxes indicate flow direction.
struct EnergyFlowView: View {
    let metrics: DashboardMetrics

    // Derived power values
    private var solar: Double { metrics.solarPowerWatts ?? 0 }
    private var battery: Double { metrics.batteryPowerWatts ?? 0 } // positive=charging, negative=discharging
    private var soc: Double? { metrics.stateOfCharge }

    private var generatorActive: Bool { battery > 10 && battery > solar + 10 }
    private var generatorWatts: Double { max(0, battery - solar) }

    private var loadsWatts: Double {
        if battery >= 0 {
            return max(0, solar - battery)
        } else {
            return solar + abs(battery)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let spacing: CGFloat = 12
            let boxW = (w - spacing) / 2
            let boxH: CGFloat = 140
            let totalH = boxH * 2 + spacing

            ZStack(alignment: .topLeading) {
                // --- Flow arrows (drawn behind boxes) ---

                // Solar -> Battery (vertical, left column)
                if solar > 5 {
                    ArrowLine(
                        from: CGPoint(x: boxW / 2, y: boxH),
                        to: CGPoint(x: boxW / 2, y: boxH + spacing),
                        color: VTheme.solarColor
                    )
                }

                // Generator -> Battery (diagonal, top-right to bottom-left)
                if generatorActive {
                    ArrowLine(
                        from: CGPoint(x: boxW + spacing + boxW * 0.3, y: boxH),
                        to: CGPoint(x: boxW * 0.7, y: boxH + spacing),
                        color: VTheme.generatorColor
                    )
                }

                // Battery -> Loads (horizontal, bottom row)
                if loadsWatts > 5 {
                    ArrowLine(
                        from: CGPoint(x: boxW, y: boxH + spacing + boxH / 2),
                        to: CGPoint(x: boxW + spacing, y: boxH + spacing + boxH / 2),
                        color: VTheme.loadsColor
                    )
                }

                // --- Boxes ---

                // Top-left: Solar
                EnergyBox(
                    icon: "sun.max.fill",
                    title: "Solar",
                    mainValue: solar > 0 ? "\(Int(solar)) W" : "0 W",
                    subtitle: metrics.chargeState,
                    accentColor: VTheme.solarColor,
                    active: solar > 0
                )
                .frame(width: boxW, height: boxH)
                .offset(x: 0, y: 0)

                // Top-right: Generator
                EnergyBox(
                    icon: "powerplug.fill",
                    title: "Generator",
                    mainValue: generatorActive ? "\(Int(generatorWatts)) W" : "-- W",
                    subtitle: generatorActive ? "Active" : "Inactive",
                    accentColor: VTheme.generatorColor,
                    active: generatorActive
                )
                .frame(width: boxW, height: boxH)
                .offset(x: boxW + spacing, y: 0)

                // Bottom-left: Battery
                BatteryBox(
                    soc: soc,
                    watts: battery,
                    accentColor: VTheme.batteryColor
                )
                .frame(width: boxW, height: boxH)
                .offset(x: 0, y: boxH + spacing)

                // Bottom-right: Loads
                EnergyBox(
                    icon: "house.fill",
                    title: "Loads",
                    mainValue: loadsWatts > 0 ? "\(Int(loadsWatts)) W" : "0 W",
                    subtitle: generatorActive ? "~estimated" : nil,
                    accentColor: VTheme.loadsColor,
                    active: loadsWatts > 5
                )
                .frame(width: boxW, height: boxH)
                .offset(x: boxW + spacing, y: boxH + spacing)
            }
            .frame(height: totalH)
        }
        .frame(height: 140 * 2 + 12)
    }
}

// MARK: - Energy Box (Victron GUI V2 style)

struct EnergyBox: View {
    let icon: String
    let title: String
    let mainValue: String
    var subtitle: String? = nil
    let accentColor: Color
    var active: Bool = true

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(active ? accentColor : VTheme.gray5)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(active ? .white : VTheme.gray5)
                Spacer()
            }

            Spacer()

            Text(mainValue)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(active ? .white : VTheme.gray5.opacity(0.5))
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if let sub = subtitle {
                Text(sub)
                    .font(.system(size: 12))
                    .foregroundColor(VTheme.gray5)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: VTheme.cornerRadius)
                .fill(VTheme.widgetBG)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VTheme.cornerRadius)
                .stroke(active ? accentColor.opacity(0.6) : VTheme.gray5.opacity(0.3),
                         lineWidth: VTheme.borderWidth)
        )
    }
}

// MARK: - Battery Box (SOC fill + watts)

struct BatteryBox: View {
    let soc: Double?
    let watts: Double
    let accentColor: Color

    var body: some View {
        ZStack(alignment: .bottom) {
            // SOC fill background
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(accentColor.opacity(0.2))
                        .frame(height: geo.size.height * CGFloat((soc ?? 0) / 100))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: VTheme.cornerRadius))

            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "battery.75percent")
                        .font(.system(size: 16))
                        .foregroundColor(accentColor)
                    Text("Battery")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                }

                Spacer()

                Text(soc != nil ? "\(Int(soc!))%" : "--%")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(formatBatteryWatts(watts))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(watts >= 0 ? VTheme.green : VTheme.red)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: VTheme.cornerRadius)
                .fill(VTheme.widgetBG)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VTheme.cornerRadius)
                .stroke(accentColor.opacity(0.6), lineWidth: VTheme.borderWidth)
        )
    }

    private func formatBatteryWatts(_ w: Double) -> String {
        let prefix = w >= 0 ? "+" : ""
        return "\(prefix)\(Int(w)) W"
    }
}

// MARK: - Arrow Line (static arrow showing flow direction)

struct ArrowLine: View {
    let from: CGPoint
    let to: CGPoint
    let color: Color

    var body: some View {
        ZStack {
            // Line
            Path { path in
                path.move(to: from)
                path.addLine(to: to)
            }
            .stroke(color.opacity(0.5), lineWidth: 2.5)

            // Arrowhead at the "to" end
            let angle = atan2(to.y - from.y, to.x - from.x)
            let arrowLen: CGFloat = 10
            let arrowAngle: CGFloat = .pi / 5

            Path { path in
                path.move(to: to)
                path.addLine(to: CGPoint(
                    x: to.x - arrowLen * cos(angle - arrowAngle),
                    y: to.y - arrowLen * sin(angle - arrowAngle)
                ))
                path.move(to: to)
                path.addLine(to: CGPoint(
                    x: to.x - arrowLen * cos(angle + arrowAngle),
                    y: to.y - arrowLen * sin(angle + arrowAngle)
                ))
            }
            .stroke(color.opacity(0.8), lineWidth: 2.5)
        }
    }
}

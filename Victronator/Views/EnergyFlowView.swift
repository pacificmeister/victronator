import SwiftUI

/// Energy flow diagram with 4 boxes in a 2x2 grid:
///   [Solar]      [Generator]
///   [Battery]    [Loads]
/// Thick arrow lines between boxes show flow direction.
struct EnergyFlowView: View {
    let metrics: DashboardMetrics
    let availableHeight: CGFloat

    // Derived power values
    private var solar: Double { metrics.solarPowerWatts ?? 0 }
    private var battery: Double { metrics.batteryPowerWatts ?? 0 }
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
            let h = availableHeight
            let lineGap: CGFloat = 36
            let boxW = (w - lineGap) / 2
            let boxH = (h - lineGap) / 2

            ZStack(alignment: .topLeading) {
                // --- Arrow lines (drawn first, behind boxes) ---

                // Solar -> Battery (vertical, left column center)
                ArrowLine(
                    from: CGPoint(x: boxW / 2, y: boxH + 2),
                    to: CGPoint(x: boxW / 2, y: boxH + lineGap - 2),
                    watts: solar > 5 ? min(solar, max(battery, 0) + loadsWatts) : 0,
                    color: VTheme.solarColor,
                    active: solar > 5
                )

                // Generator -> Battery (diagonal)
                ArrowLine(
                    from: CGPoint(x: boxW + lineGap + boxW * 0.25, y: boxH + 2),
                    to: CGPoint(x: boxW * 0.75, y: boxH + lineGap - 2),
                    watts: generatorWatts,
                    color: VTheme.generatorColor,
                    active: generatorActive
                )

                // Battery -> Loads (horizontal, bottom row)
                ArrowLine(
                    from: CGPoint(x: boxW + 2, y: boxH + lineGap + boxH / 2),
                    to: CGPoint(x: boxW + lineGap - 2, y: boxH + lineGap + boxH / 2),
                    watts: loadsWatts,
                    color: VTheme.loadsColor,
                    active: loadsWatts > 5
                )

                // --- Boxes ---

                EnergyBox(
                    icon: "sun.max.fill", title: "Solar",
                    mainValue: solar > 0 ? "\(Int(solar)) W" : "0 W",
                    subtitle: metrics.chargeState,
                    accentColor: VTheme.solarColor, active: solar > 0
                )
                .frame(width: boxW, height: boxH)
                .offset(x: 0, y: 0)

                EnergyBox(
                    icon: "powerplug.fill", title: "Generator",
                    mainValue: generatorActive ? "\(Int(generatorWatts)) W" : "-- W",
                    subtitle: generatorActive ? "Active" : "Inactive",
                    accentColor: VTheme.generatorColor, active: generatorActive
                )
                .frame(width: boxW, height: boxH)
                .offset(x: boxW + lineGap, y: 0)

                BatteryBox(soc: soc, watts: battery, accentColor: VTheme.batteryColor)
                    .frame(width: boxW, height: boxH)
                    .offset(x: 0, y: boxH + lineGap)

                EnergyBox(
                    icon: "house.fill", title: "Loads",
                    mainValue: loadsWatts > 0 ? "\(Int(loadsWatts)) W" : "0 W",
                    subtitle: generatorActive ? "~estimated" : nil,
                    accentColor: VTheme.loadsColor, active: loadsWatts > 5
                )
                .frame(width: boxW, height: boxH)
                .offset(x: boxW + lineGap, y: boxH + lineGap)
            }
        }
        .frame(height: availableHeight)
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
                    .font(.system(size: 18))
                    .foregroundColor(active ? accentColor : VTheme.gray5)
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(active ? .white : VTheme.gray5)
                Spacer()
            }

            Spacer()

            Text(mainValue)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundColor(active ? .white : VTheme.gray5.opacity(0.5))
                .minimumScaleFactor(0.4)
                .lineLimit(1)

            if let sub = subtitle {
                Text(sub)
                    .font(.system(size: 13))
                    .foregroundColor(VTheme.gray5)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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

// MARK: - Battery Box

struct BatteryBox: View {
    let soc: Double?
    let watts: Double
    let accentColor: Color

    var body: some View {
        ZStack(alignment: .bottom) {
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
                        .font(.system(size: 18))
                        .foregroundColor(accentColor)
                    Text("Battery")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                }

                Spacer()

                Text(soc != nil ? "\(Int(soc!))%" : "--%")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(formatBatteryWatts(watts))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(watts >= 0 ? VTheme.green : VTheme.red)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
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

// MARK: - Arrow Line with thick stroke and arrowhead

struct ArrowLine: View {
    let from: CGPoint
    let to: CGPoint
    let watts: Double
    let color: Color
    let active: Bool

    var body: some View {
        if active && watts > 5 {
            ZStack {
                // Thick line
                Path { path in
                    path.move(to: from)
                    path.addLine(to: to)
                }
                .stroke(color.opacity(0.6), lineWidth: 4)

                // Glow effect
                Path { path in
                    path.move(to: from)
                    path.addLine(to: to)
                }
                .stroke(color.opacity(0.2), lineWidth: 10)

                // Arrowhead
                arrowHead
                    .fill(color.opacity(0.8))

                // (arrow + line only, no label — values shown in boxes)
            }
        } else {
            // Inactive: thin dashed line, no arrow
            Path { path in
                path.move(to: from)
                path.addLine(to: to)
            }
            .stroke(VTheme.gray5.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
    }

    private var arrowHead: Path {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let arrowLen: CGFloat = 14
        let arrowAngle: CGFloat = .pi / 5
        let tip = to

        return Path { path in
            path.move(to: tip)
            path.addLine(to: CGPoint(
                x: tip.x - arrowLen * cos(angle - arrowAngle),
                y: tip.y - arrowLen * sin(angle - arrowAngle)
            ))
            path.addLine(to: CGPoint(
                x: tip.x - arrowLen * cos(angle + arrowAngle),
                y: tip.y - arrowLen * sin(angle + arrowAngle)
            ))
            path.closeSubpath()
        }
    }

}

import SwiftUI

/// Energy flow diagram with 4 boxes in a 2x2 grid:
///   [Solar]      [Generator]
///   [Battery]    [Loads]
/// Lines: Solar->Battery (vertical), Generator->Battery (diagonal), Battery->Loads (horizontal)
struct EnergyFlowView: View {
    let metrics: DashboardMetrics

    @State private var flowPhase: CGFloat = 0

    // Derived power values
    private var solar: Double { metrics.solarPowerWatts ?? 0 }
    private var battery: Double { metrics.batteryPowerWatts ?? 0 } // positive=charging, negative=discharging
    private var soc: Double? { metrics.stateOfCharge }

    /// Generator detected when battery charging exceeds solar
    private var generatorActive: Bool { battery > 10 && battery > solar + 10 }
    private var generatorWatts: Double { max(0, battery - solar) }

    /// Loads estimate
    private var loadsWatts: Double {
        if battery >= 0 {
            // Battery charging: loads = solar - battery (what solar feeds beyond charging)
            return max(0, solar - battery)
        } else {
            // Battery discharging: loads = solar + |discharge|
            return solar + abs(battery)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h: CGFloat = 220
            let boxW: CGFloat = (w - 48) / 2
            let boxH: CGFloat = 90
            let gap: CGFloat = 16

            // Box positions (center points)
            let solarCenter = CGPoint(x: boxW / 2 + 16, y: boxH / 2)
            let genCenter = CGPoint(x: w - boxW / 2 - 16, y: boxH / 2)
            let battCenter = CGPoint(x: boxW / 2 + 16, y: h - boxH / 2)
            let loadsCenter = CGPoint(x: w - boxW / 2 - 16, y: h - boxH / 2)

            ZStack {
                // Flow lines (behind boxes)
                // Solar -> Battery (vertical, left column)
                FlowConnector(
                    from: CGPoint(x: solarCenter.x, y: solarCenter.y + boxH / 2),
                    to: CGPoint(x: battCenter.x, y: battCenter.y - boxH / 2),
                    watts: solar > 0 && battery >= 0 ? min(solar, battery) : (solar > 0 ? solar : 0),
                    color: VTheme.solarColor,
                    active: solar > 5,
                    phase: flowPhase,
                    direction: .forward
                )

                // Generator -> Battery (diagonal)
                FlowConnector(
                    from: CGPoint(x: genCenter.x - boxW / 2, y: genCenter.y + boxH / 2),
                    to: CGPoint(x: battCenter.x + boxW / 2, y: battCenter.y - boxH / 2 + 10),
                    watts: generatorWatts,
                    color: VTheme.generatorColor,
                    active: generatorActive,
                    phase: flowPhase,
                    direction: .forward
                )

                // Battery -> Loads (horizontal, bottom row)
                FlowConnector(
                    from: CGPoint(x: battCenter.x + boxW / 2, y: loadsCenter.y),
                    to: CGPoint(x: loadsCenter.x - boxW / 2, y: loadsCenter.y),
                    watts: loadsWatts,
                    color: VTheme.loadsColor,
                    active: loadsWatts > 5,
                    phase: flowPhase,
                    direction: battery < 0 ? .forward : .forward
                )

                // Boxes
                EnergyBox(
                    icon: "sun.max.fill",
                    title: "Solar",
                    mainValue: solar > 0 ? "\(Int(solar)) W" : "0 W",
                    subtitle: metrics.chargeState,
                    accentColor: VTheme.solarColor,
                    active: solar > 0
                )
                .frame(width: boxW, height: boxH)
                .position(solarCenter)

                EnergyBox(
                    icon: "powerplug.fill",
                    title: "Generator",
                    mainValue: generatorActive ? "\(Int(generatorWatts)) W" : "-- W",
                    subtitle: generatorActive ? "Active" : "Inactive",
                    accentColor: VTheme.generatorColor,
                    active: generatorActive
                )
                .frame(width: boxW, height: boxH)
                .position(genCenter)

                BatteryBox(
                    soc: soc,
                    watts: battery,
                    accentColor: VTheme.batteryColor
                )
                .frame(width: boxW, height: boxH)
                .position(battCenter)

                EnergyBox(
                    icon: "house.fill",
                    title: "Loads",
                    mainValue: loadsWatts > 0 ? "\(Int(loadsWatts)) W" : "0 W",
                    subtitle: generatorActive ? "~estimated" : nil,
                    accentColor: VTheme.loadsColor,
                    active: loadsWatts > 5
                )
                .frame(width: boxW, height: boxH)
                .position(loadsCenter)
            }
            .frame(height: h)
        }
        .frame(height: 220)
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                flowPhase = 1
            }
        }
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
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(active ? accentColor : VTheme.gray5)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(active ? .white : VTheme.gray5)
                Spacer()
            }

            Spacer()

            Text(mainValue)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(active ? .white : VTheme.gray5.opacity(0.6))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            if let sub = subtitle {
                Text(sub)
                    .font(.system(size: 10))
                    .foregroundColor(VTheme.gray5)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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

// MARK: - Battery Box (special: shows SOC + watts)

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

            // Content
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "battery.75percent")
                        .font(.system(size: 14))
                        .foregroundColor(accentColor)
                    Text("Battery")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                }

                Spacer()

                Text(soc != nil ? "\(Int(soc!))%" : "--%")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(formatBatteryWatts(watts))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(watts >= 0 ? VTheme.green : VTheme.red)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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

// MARK: - Flow Connector (animated particles along a line)

struct FlowConnector: View {
    let from: CGPoint
    let to: CGPoint
    let watts: Double
    let color: Color
    let active: Bool
    let phase: CGFloat
    let direction: FlowDirection

    enum FlowDirection {
        case forward, reverse
    }

    var body: some View {
        ZStack {
            // Static line
            Path { path in
                path.move(to: from)
                path.addLine(to: to)
            }
            .stroke(
                active ? color.opacity(0.3) : VTheme.gray5.opacity(0.15),
                lineWidth: 2
            )

            // Animated particles (only when active and watts > threshold)
            if active && watts > 5 {
                ForEach(0..<4, id: \.self) { i in
                    let offset = CGFloat(i) / 4.0
                    let raw = direction == .forward
                        ? (phase + offset).truncatingRemainder(dividingBy: 1.0)
                        : (1 - phase + offset).truncatingRemainder(dividingBy: 1.0)
                    let t = raw < 0 ? raw + 1 : raw

                    Circle()
                        .fill(color)
                        .frame(width: particleSize, height: particleSize)
                        .shadow(color: color.opacity(0.6), radius: 3)
                        .position(
                            x: from.x + (to.x - from.x) * t,
                            y: from.y + (to.y - from.y) * t
                        )
                        .opacity(fadeEdges(t))
                }
            }
        }
    }

    private var particleSize: CGFloat {
        CGFloat(min(max(watts / 150, 4), 8))
    }

    // Fade particles near start/end
    private func fadeEdges(_ t: CGFloat) -> Double {
        let fade: CGFloat = 0.1
        if t < fade { return Double(t / fade) }
        if t > 1 - fade { return Double((1 - t) / fade) }
        return 1
    }
}

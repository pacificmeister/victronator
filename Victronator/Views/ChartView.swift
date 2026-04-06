import SwiftUI

/// Custom 24-hour line chart with dual Y-axes.
/// Left Y: SOC (0-100%). Right Y: Watts.
/// Compatible with iOS 15+.
struct ChartView: View {
    let points: [DataPoint]

    private let chartHeight: CGFloat = 200
    private let leftPadding: CGFloat = 40
    private let rightPadding: CGFloat = 50
    private let bottomPadding: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Legend
            HStack(spacing: 16) {
                LegendDot(color: .green, label: "SOC %")
                LegendDot(color: .orange, label: "Solar W")
                LegendDot(color: .red, label: "Battery W")
                LegendDot(color: .purple, label: "Consumer W")
            }
            .font(.caption2)
            .padding(.horizontal, 4)

            GeometryReader { geo in
                let width = geo.size.width - leftPadding - rightPadding
                let height = chartHeight - bottomPadding

                ZStack(alignment: .topLeading) {
                    // Grid lines
                    gridLines(width: width, height: height)
                        .offset(x: leftPadding)

                    // SOC line (left Y: 0-100%)
                    linePath(
                        points: points,
                        width: width,
                        height: height,
                        valueFor: { $0.soc },
                        minVal: 0, maxVal: 100
                    )
                    .stroke(Color.green, lineWidth: 2)
                    .offset(x: leftPadding)

                    // Solar line (right Y: watts)
                    let wattRange = wattAxisRange
                    linePath(
                        points: points,
                        width: width,
                        height: height,
                        valueFor: { $0.solarWatts },
                        minVal: 0, maxVal: wattRange
                    )
                    .stroke(Color.orange, lineWidth: 1.5)
                    .offset(x: leftPadding)

                    // Battery line
                    linePath(
                        points: points,
                        width: width,
                        height: height,
                        valueFor: { $0.batteryWatts.map { abs($0) } },
                        minVal: 0, maxVal: wattRange
                    )
                    .stroke(Color.red.opacity(0.8), lineWidth: 1.5)
                    .offset(x: leftPadding)

                    // Consumer line
                    linePath(
                        points: points,
                        width: width,
                        height: height,
                        valueFor: { $0.consumerWatts },
                        minVal: 0, maxVal: wattRange
                    )
                    .stroke(Color.purple.opacity(0.8), lineWidth: 1.5)
                    .offset(x: leftPadding)

                    // Left Y-axis labels (SOC %)
                    VStack {
                        Text("100%").font(.system(size: 9))
                        Spacer()
                        Text("50%").font(.system(size: 9))
                        Spacer()
                        Text("0%").font(.system(size: 9))
                    }
                    .foregroundColor(.green.opacity(0.7))
                    .frame(width: leftPadding - 4, height: height)

                    // Right Y-axis labels (Watts)
                    VStack {
                        Text("\(Int(wattAxisRange))W").font(.system(size: 9))
                        Spacer()
                        Text("\(Int(wattAxisRange / 2))W").font(.system(size: 9))
                        Spacer()
                        Text("0W").font(.system(size: 9))
                    }
                    .foregroundColor(.orange.opacity(0.7))
                    .frame(width: rightPadding - 4, height: height)
                    .offset(x: leftPadding + width + 4)

                    // Time labels
                    timeLabels(width: width)
                        .offset(x: leftPadding, y: height + 4)
                }
            }
            .frame(height: chartHeight)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground).opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Drawing

    private func linePath(
        points: [DataPoint],
        width: CGFloat,
        height: CGFloat,
        valueFor: (DataPoint) -> Double?,
        minVal: Double,
        maxVal: Double
    ) -> Path {
        let range = maxVal - minVal
        guard range > 0, !points.isEmpty else { return Path() }

        let now = Date()
        let window: TimeInterval = 24 * 60 * 60

        return Path { path in
            var started = false
            for point in points {
                guard let val = valueFor(point) else { continue }
                let age = now.timeIntervalSince(point.timestamp)
                let x = (1 - age / window) * Double(width)
                let y = (1 - (val - minVal) / range) * Double(height)

                guard x >= 0 else { continue }

                if !started {
                    path.move(to: CGPoint(x: x, y: y))
                    started = true
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }

    private func gridLines(width: CGFloat, height: CGFloat) -> some View {
        Path { path in
            // Horizontal lines at 25%, 50%, 75%
            for frac in [0.25, 0.5, 0.75] {
                let y = height * CGFloat(frac)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
            }
        }
        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
    }

    private func timeLabels(width: CGFloat) -> some View {
        HStack {
            Text("-24h").font(.system(size: 8))
            Spacer()
            Text("-18h").font(.system(size: 8))
            Spacer()
            Text("-12h").font(.system(size: 8))
            Spacer()
            Text("-6h").font(.system(size: 8))
            Spacer()
            Text("Now").font(.system(size: 8))
        }
        .foregroundColor(.secondary)
        .frame(width: width)
    }

    private var wattAxisRange: Double {
        let maxW = points.compactMap { p -> Double? in
            let vals = [p.solarWatts, p.batteryWatts.map { abs($0) }, p.consumerWatts].compactMap { $0 }
            return vals.max()
        }.max() ?? 500

        // Round up to nice number
        let steps: [Double] = [100, 200, 500, 1000, 1500, 2000, 3000, 5000, 10000]
        return steps.first { $0 >= maxW * 1.1 } ?? maxW * 1.2
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
        }
    }
}

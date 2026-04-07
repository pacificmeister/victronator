import SwiftUI

/// 24-hour history chart with dual Y-axes.
/// Left Y: SOC (fixed 0-100%). Right Y: Watts (auto-scaled).
/// Gaps where app wasn't running are shaded and lines broken.
struct ChartView: View {
    let points: [DataPoint]

    private let chartHeight: CGFloat = 300
    private let leftPad: CGFloat = 36
    private let rightPad: CGFloat = 44
    private let topPad: CGFloat = 8
    private let bottomPad: CGFloat = 20
    private let gapThreshold: TimeInterval = 60 // 60s = gap

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Legend
            HStack(spacing: 14) {
                LegendItem(color: VTheme.green, label: "SOC %")
                LegendItem(color: VTheme.solarColor, label: "Solar")
                LegendItem(color: VTheme.red, label: "Battery")
                LegendItem(color: VTheme.loadsColor, label: "Loads")
            }
            .font(.system(size: 10))

            GeometryReader { geo in
                let plotW = geo.size.width - leftPad - rightPad
                let plotH = chartHeight - topPad - bottomPad
                let wMax = wattAxisMax

                ZStack(alignment: .topLeading) {
                    // Gap shading
                    gapRegions(plotW: plotW, plotH: plotH)
                        .offset(x: leftPad, y: topPad)

                    // Grid lines
                    gridLines(plotW: plotW, plotH: plotH)
                        .offset(x: leftPad, y: topPad)

                    // SOC line (left Y: 0-100, fixed)
                    segmentedLine(plotW: plotW, plotH: plotH,
                                  valueFor: { $0.soc },
                                  minVal: 0, maxVal: 100,
                                  color: VTheme.green, width: 2.5)
                        .offset(x: leftPad, y: topPad)

                    // Solar line (right Y: auto-scaled watts)
                    segmentedLine(plotW: plotW, plotH: plotH,
                                  valueFor: { $0.solarWatts },
                                  minVal: 0, maxVal: wMax,
                                  color: VTheme.solarColor, width: 1.5)
                        .offset(x: leftPad, y: topPad)

                    // Battery line (absolute watts)
                    segmentedLine(plotW: plotW, plotH: plotH,
                                  valueFor: { $0.batteryWatts.map { abs($0) } },
                                  minVal: 0, maxVal: wMax,
                                  color: VTheme.red, width: 1.5)
                        .offset(x: leftPad, y: topPad)

                    // Loads line
                    segmentedLine(plotW: plotW, plotH: plotH,
                                  valueFor: { $0.consumerWatts },
                                  minVal: 0, maxVal: wMax,
                                  color: VTheme.loadsColor, width: 1.5)
                        .offset(x: leftPad, y: topPad)

                    // Left Y-axis (SOC %)
                    VStack(alignment: .trailing) {
                        Text("100").font(.system(size: 8))
                        Spacer()
                        Text("75").font(.system(size: 8))
                        Spacer()
                        Text("50").font(.system(size: 8))
                        Spacer()
                        Text("25").font(.system(size: 8))
                        Spacer()
                        Text("0").font(.system(size: 8))
                    }
                    .foregroundColor(VTheme.green.opacity(0.6))
                    .frame(width: leftPad - 6, height: plotH)
                    .offset(y: topPad)

                    // Right Y-axis (Watts, auto-scaled)
                    VStack(alignment: .leading) {
                        Text(formatAxisW(wMax)).font(.system(size: 8))
                        Spacer()
                        Text(formatAxisW(wMax * 0.5)).font(.system(size: 8))
                        Spacer()
                        Text("0").font(.system(size: 8))
                    }
                    .foregroundColor(VTheme.solarColor.opacity(0.6))
                    .frame(width: rightPad - 6, height: plotH)
                    .offset(x: leftPad + plotW + 6, y: topPad)

                    // Time axis
                    HStack {
                        Text("-24h")
                        Spacer()
                        Text("-18h")
                        Spacer()
                        Text("-12h")
                        Spacer()
                        Text("-6h")
                        Spacer()
                        Text("Now")
                    }
                    .font(.system(size: 8))
                    .foregroundColor(VTheme.gray5)
                    .frame(width: plotW)
                    .offset(x: leftPad, y: topPad + plotH + 4)
                }
            }
            .frame(height: chartHeight)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: VTheme.cornerRadius)
                .fill(VTheme.widgetBG)
                .overlay(
                    RoundedRectangle(cornerRadius: VTheme.cornerRadius)
                        .stroke(VTheme.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Segmented line (breaks at gaps)

    private func segmentedLine(plotW: CGFloat, plotH: CGFloat,
                                valueFor: (DataPoint) -> Double?,
                                minVal: Double, maxVal: Double,
                                color: Color, width: CGFloat) -> some View {
        let range = maxVal - minVal
        let now = Date()
        let window: TimeInterval = 24 * 60 * 60

        let path = Path { path in
            var prevTime: Date? = nil
            var inSegment = false

            for point in points {
                guard let val = valueFor(point) else {
                    inSegment = false
                    prevTime = point.timestamp
                    continue
                }

                let age = now.timeIntervalSince(point.timestamp)
                let x = (1 - age / window) * Double(plotW)
                let y = range > 0 ? (1 - (val - minVal) / range) * Double(plotH) : Double(plotH) / 2

                guard x >= 0 && x <= Double(plotW) else {
                    prevTime = point.timestamp
                    continue
                }

                // Check for gap
                let isGap = prevTime != nil && point.timestamp.timeIntervalSince(prevTime!) > gapThreshold

                if !inSegment || isGap {
                    path.move(to: CGPoint(x: x, y: y))
                    inSegment = true
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                prevTime = point.timestamp
            }
        }

        return path.stroke(color, lineWidth: width)
    }

    // MARK: - Gap regions (shaded)

    private func gapRegions(plotW: CGFloat, plotH: CGFloat) -> some View {
        let now = Date()
        let window: TimeInterval = 24 * 60 * 60

        var rects: [(CGFloat, CGFloat)] = [] // (x start, x end)
        var prevTime: Date? = nil

        for point in points {
            if let prev = prevTime, point.timestamp.timeIntervalSince(prev) > gapThreshold {
                let x1 = (1 - now.timeIntervalSince(prev) / window) * Double(plotW)
                let x2 = (1 - now.timeIntervalSince(point.timestamp) / window) * Double(plotW)
                if x1 >= 0 || x2 >= 0 {
                    rects.append((CGFloat(max(x2, 0)), CGFloat(min(x1, Double(plotW)))))
                }
            }
            prevTime = point.timestamp
        }

        return ZStack {
            ForEach(Array(rects.enumerated()), id: \.offset) { _, rect in
                Rectangle()
                    .fill(Color.white.opacity(0.03))
                    .frame(width: max(0, rect.1 - rect.0), height: plotH)
                    .offset(x: rect.0 + (rect.1 - rect.0) / 2 - plotW / 2)
            }
        }
        .frame(width: plotW, height: plotH)
    }

    // MARK: - Grid

    private func gridLines(plotW: CGFloat, plotH: CGFloat) -> some View {
        Path { path in
            for frac in [0.25, 0.5, 0.75] {
                let y = plotH * CGFloat(frac)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: plotW, y: y))
            }
        }
        .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
    }

    // MARK: - Watt axis auto-scale

    private var wattAxisMax: Double {
        let maxW = points.compactMap { p -> Double? in
            [p.solarWatts, p.batteryWatts.map { abs($0) }, p.consumerWatts]
                .compactMap { $0 }.max()
        }.max() ?? 500

        let steps: [Double] = [50, 100, 200, 300, 500, 750, 1000, 1500, 2000, 3000, 5000, 10000]
        return steps.first { $0 >= maxW * 1.1 } ?? maxW * 1.2
    }

    private func formatAxisW(_ w: Double) -> String {
        if w >= 1000 { return "\(Int(w / 1000))kW" }
        return "\(Int(w))W"
    }
}

private struct LegendItem: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 12, height: 3)
            Text(label).foregroundColor(VTheme.gray5)
        }
    }
}

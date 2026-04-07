import SwiftUI

/// 24-hour history chart with dual Y-axes.
/// Left Y: SOC (fixed 0-100%). Right Y: Watts (auto-scaled).
/// X-axis shows real clock times in device timezone.
/// Gaps where app wasn't running are shaded gray with broken lines.
struct ChartView: View {
    let points: [DataPoint]
    var chartHeight: CGFloat = 300

    private let leftPad: CGFloat = 36
    private let rightPad: CGFloat = 44
    private let topPad: CGFloat = 24  // room for legend
    private let bottomPad: CGFloat = 24
    private let gapThreshold: TimeInterval = 60

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = .current
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Legend row
            HStack(spacing: 14) {
                LegendItem(color: VTheme.green, label: "SOC %")
                LegendItem(color: VTheme.solarColor, label: "Solar")
                LegendItem(color: VTheme.red, label: "Battery")
                LegendItem(color: VTheme.loadsColor, label: "Loads")
            }
            .font(.system(size: 10))
            .padding(.bottom, 4)

            GeometryReader { geo in
                let totalW = geo.size.width
                let totalH = geo.size.height
                let plotW = totalW - leftPad - rightPad
                let plotH = totalH - bottomPad
                let wRange = wattAxisRange // (min, max)

                ZStack(alignment: .topLeading) {
                    // Gap shading (gray regions where no data)
                    gapRegions(plotW: plotW, plotH: plotH)
                        .offset(x: leftPad)

                    // Also shade the region before first data point
                    leadingGap(plotW: plotW, plotH: plotH)
                        .offset(x: leftPad)

                    // Grid lines + zero line
                    gridLines(plotW: plotW, plotH: plotH, wMin: wRange.min, wMax: wRange.max)
                        .offset(x: leftPad)

                    // Data lines
                    segmentedLine(plotW: plotW, plotH: plotH,
                                  valueFor: { $0.soc },
                                  minVal: 0, maxVal: 100,
                                  color: VTheme.green, width: 2.5)
                        .offset(x: leftPad)

                    segmentedLine(plotW: plotW, plotH: plotH,
                                  valueFor: { $0.solarWatts },
                                  minVal: wRange.min, maxVal: wRange.max,
                                  color: VTheme.solarColor, width: 1.5)
                        .offset(x: leftPad)

                    // Battery: signed watts (negative = discharging)
                    segmentedLine(plotW: plotW, plotH: plotH,
                                  valueFor: { $0.batteryWatts },
                                  minVal: wRange.min, maxVal: wRange.max,
                                  color: VTheme.red, width: 1.5)
                        .offset(x: leftPad)

                    segmentedLine(plotW: plotW, plotH: plotH,
                                  valueFor: { $0.consumerWatts },
                                  minVal: wRange.min, maxVal: wRange.max,
                                  color: VTheme.loadsColor, width: 1.5)
                        .offset(x: leftPad)

                    // Left Y-axis (SOC %)
                    yAxisLabels(
                        values: ["100", "75", "50", "25", "0"],
                        color: VTheme.green.opacity(0.6),
                        width: leftPad - 6,
                        height: plotH,
                        alignment: .trailing
                    )

                    // Right Y-axis (Watts, includes negative)
                    yAxisLabels(
                        values: wAxisLabels(wRange),
                        color: VTheme.solarColor.opacity(0.6),
                        width: rightPad - 6,
                        height: plotH,
                        alignment: .leading
                    )
                    .offset(x: leftPad + plotW + 6)

                    // X-axis: real clock times
                    timeAxis(plotW: plotW)
                        .offset(x: leftPad, y: plotH + 4)
                }
            }
            .frame(height: chartHeight - 24) // minus legend height
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

    // MARK: - X-axis with real clock times

    private func timeAxis(plotW: CGFloat) -> some View {
        let now = Date()
        let window: TimeInterval = 24 * 60 * 60

        // Generate labels at 3-hour intervals
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)

        // Find the most recent 3-hour mark
        let lastMark = currentHour - (currentHour % 3)
        var labels: [(String, CGFloat)] = []

        for i in 0..<9 { // 0, 3, 6, ... 24 hours back
            let hoursBack = i * 3
            let markHour = (lastMark - hoursBack + 48) % 24
            let age = TimeInterval(currentHour - lastMark + hoursBack) * 3600
                + TimeInterval(calendar.component(.minute, from: now)) * 60

            let x = (1 - age / window) * Double(plotW)
            guard x >= 0 && x <= Double(plotW) else { continue }

            let label = String(format: "%02d:00", markHour)
            labels.append((label, CGFloat(x)))
        }

        // Always add "Now" at the right edge
        labels.append(("Now", plotW))

        return ZStack(alignment: .leading) {
            ForEach(Array(labels.enumerated()), id: \.offset) { _, item in
                Text(item.0)
                    .font(.system(size: 8))
                    .foregroundColor(VTheme.gray5)
                    .position(x: item.1, y: 8)
            }
        }
        .frame(width: plotW, height: 16)
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

    // MARK: - Gap regions (shaded gray)

    private func gapRegions(plotW: CGFloat, plotH: CGFloat) -> some View {
        let now = Date()
        let window: TimeInterval = 24 * 60 * 60
        var rects: [(x: CGFloat, w: CGFloat)] = []
        var prevTime: Date? = nil

        for point in points {
            if let prev = prevTime, point.timestamp.timeIntervalSince(prev) > gapThreshold {
                let x1 = CGFloat((1 - now.timeIntervalSince(prev) / window) * Double(plotW))
                let x2 = CGFloat((1 - now.timeIntervalSince(point.timestamp) / window) * Double(plotW))
                let left = max(0, min(x1, x2))
                let right = min(plotW, max(x1, x2))
                if right > left {
                    rects.append((x: left, w: right - left))
                }
            }
            prevTime = point.timestamp
        }

        return ZStack(alignment: .topLeading) {
            ForEach(Array(rects.enumerated()), id: \.offset) { _, rect in
                Rectangle()
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: rect.w, height: plotH)
                    .offset(x: rect.x)
            }
        }
        .frame(width: plotW, height: plotH, alignment: .topLeading)
    }

    /// Shade the region before the first data point (no data existed yet)
    private func leadingGap(plotW: CGFloat, plotH: CGFloat) -> some View {
        let now = Date()
        let window: TimeInterval = 24 * 60 * 60

        guard let first = points.first else {
            return AnyView(
                Rectangle()
                    .fill(Color.gray.opacity(0.08))
                    .frame(width: plotW, height: plotH)
            )
        }

        let age = now.timeIntervalSince(first.timestamp)
        let x = CGFloat((1 - age / window) * Double(plotW))

        if x > 1 {
            return AnyView(
                Rectangle()
                    .fill(Color.gray.opacity(0.08))
                    .frame(width: x, height: plotH)
            )
        }
        return AnyView(EmptyView())
    }

    // MARK: - Grid (with zero line when axis includes negatives)

    private func gridLines(plotW: CGFloat, plotH: CGFloat, wMin: Double, wMax: Double) -> some View {
        let range = wMax - wMin
        return ZStack {
            // Standard grid at 25/50/75%
            Path { path in
                for frac in [0.25, 0.5, 0.75] {
                    let y = plotH * CGFloat(frac)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: plotW, y: y))
                }
            }
            .stroke(Color.white.opacity(0.05), lineWidth: 0.5)

            // Zero line (if axis spans negative to positive)
            if wMin < 0 && range > 0 {
                let zeroY = CGFloat((1 - (0 - wMin) / range)) * plotH
                Path { path in
                    path.move(to: CGPoint(x: 0, y: zeroY))
                    path.addLine(to: CGPoint(x: plotW, y: zeroY))
                }
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
            }
        }
    }

    // MARK: - Y-axis helper

    private func yAxisLabels(values: [String], color: Color,
                              width: CGFloat, height: CGFloat,
                              alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment) {
            ForEach(Array(values.enumerated()), id: \.offset) { i, val in
                if i > 0 { Spacer() }
                Text(val).font(.system(size: 8))
            }
        }
        .foregroundColor(color)
        .frame(width: width, height: height)
    }

    // MARK: - Watt axis auto-scale (includes negative for battery discharge)

    private var wattAxisRange: (min: Double, max: Double) {
        var allMax: Double = 500
        var allMin: Double = 0

        for p in points {
            let vals = [p.solarWatts, p.batteryWatts, p.consumerWatts].compactMap { $0 }
            if let mx = vals.max() { allMax = max(allMax, mx) }
            if let mn = vals.min() { allMin = min(allMin, mn) }
        }

        // Round to nice steps
        let posSteps: [Double] = [50, 100, 200, 300, 500, 750, 1000, 1500, 2000, 3000, 5000, 10000]
        let negSteps: [Double] = [0, -50, -100, -200, -300, -500, -750, -1000, -1500, -2000, -3000]

        let niceMax = posSteps.first { $0 >= allMax * 1.1 } ?? allMax * 1.2
        let niceMin: Double
        if allMin >= 0 {
            niceMin = 0
        } else {
            niceMin = negSteps.last { $0 <= allMin * 1.1 } ?? allMin * 1.2
        }

        return (min: niceMin, max: niceMax)
    }

    private func wAxisLabels(_ range: (min: Double, max: Double)) -> [String] {
        if range.min >= 0 {
            return [formatAxisW(range.max), formatAxisW(range.max * 0.5), "0"]
        }
        // Has negative: show max, 0, min
        let mid = formatAxisW((range.max + range.min) / 2)
        return [formatAxisW(range.max), mid, formatAxisW(range.min)]
    }

    private func formatAxisW(_ w: Double) -> String {
        let v = Int(w)
        if abs(w) >= 1000 { return "\(v / 1000)kW" }
        return "\(v)W"
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

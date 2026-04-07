import SwiftUI

/// 24-hour history chart with dual Y-axes and time range selector.
/// Left Y: SOC (fixed 0-100%). Right Y: Watts (auto-scaled with negatives).
/// X-axis shows real clock times in device timezone.
/// Range buttons: 1h, 12h, 24h, 1w
struct ChartView: View {
    @ObservedObject var dataHistory: DataHistory
    var chartHeight: CGFloat = 300

    @State private var selectedRange: ChartRange = .hour24

    private let leftPad: CGFloat = 36
    private let rightPad: CGFloat = 44
    private let topPad: CGFloat = 4
    private let bottomPad: CGFloat = 24
    private let gapThreshold: TimeInterval = 60

    private var points: [DataPoint] {
        dataHistory.points(for: selectedRange)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: legend + range selector
            HStack {
                HStack(spacing: 12) {
                    LegendItem(color: VTheme.green, label: "SOC %")
                    LegendItem(color: VTheme.solarColor, label: "Solar")
                    LegendItem(color: VTheme.red, label: "Battery")
                    LegendItem(color: VTheme.loadsColor, label: "Loads")
                }
                .font(.system(size: 10))

                Spacer()

                // Range selector buttons
                HStack(spacing: 2) {
                    ForEach(ChartRange.allCases, id: \.self) { range in
                        Button(action: { selectedRange = range }) {
                            Text(range.rawValue)
                                .font(.system(size: 10, weight: selectedRange == range ? .bold : .regular))
                                .foregroundColor(selectedRange == range ? .white : VTheme.gray5)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(selectedRange == range ? VTheme.blue.opacity(0.5) : Color.clear)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.bottom, 4)

            GeometryReader { geo in
                let totalW = geo.size.width
                let totalH = geo.size.height
                let plotW = totalW - leftPad - rightPad
                let plotH = totalH - bottomPad
                let wRange = wattAxisRange

                ZStack(alignment: .topLeading) {
                    // Gap shading
                    gapRegions(plotW: plotW, plotH: plotH)
                        .offset(x: leftPad)

                    leadingGap(plotW: plotW, plotH: plotH)
                        .offset(x: leftPad)

                    // Grid + zero line
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

                    // Right Y-axis (Watts)
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
            .frame(height: chartHeight - 28) // minus legend/button row
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
        let window = selectedRange.seconds
        let calendar = Calendar.current

        // Choose label interval based on range
        let hourInterval: Int
        let labelFormat: String
        switch selectedRange {
        case .hour1:
            hourInterval = 0 // use 15-min marks
            labelFormat = "HH:mm"
        case .hour12:
            hourInterval = 2
            labelFormat = "HH:mm"
        case .hour24:
            hourInterval = 3
            labelFormat = "HH:mm"
        case .week1:
            hourInterval = 24
            labelFormat = "EEE"
        }

        var labels: [(String, CGFloat)] = []
        let formatter = DateFormatter()
        formatter.dateFormat = labelFormat
        formatter.timeZone = .current

        if hourInterval == 0 {
            // 15-minute intervals for 1h view
            let minute = calendar.component(.minute, from: now)
            let lastQuarter = minute - (minute % 15)
            for i in 0..<5 {
                let minsBack = i * 15
                let totalMinsBack = (minute - lastQuarter) + minsBack
                let age = TimeInterval(totalMinsBack * 60)
                    + TimeInterval(calendar.component(.second, from: now))
                let x = (1 - age / window) * Double(plotW)
                guard x >= 0 && x <= Double(plotW) else { continue }
                let markDate = now.addingTimeInterval(-age)
                labels.append((formatter.string(from: markDate), CGFloat(x)))
            }
        } else {
            let currentHour = calendar.component(.hour, from: now)
            let lastMark = currentHour - (currentHour % hourInterval)
            let maxSteps = Int(window / Double(hourInterval * 3600)) + 1

            for i in 0..<maxSteps {
                let hoursBack = i * hourInterval
                let age = TimeInterval(currentHour - lastMark + hoursBack) * 3600
                    + TimeInterval(calendar.component(.minute, from: now)) * 60
                let x = (1 - age / window) * Double(plotW)
                guard x >= 0 && x <= Double(plotW) else { continue }
                let markDate = now.addingTimeInterval(-age)
                labels.append((formatter.string(from: markDate), CGFloat(x)))
            }
        }

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
        let window = selectedRange.seconds

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

    // MARK: - Gap regions

    private func gapRegions(plotW: CGFloat, plotH: CGFloat) -> some View {
        let now = Date()
        let window = selectedRange.seconds
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

    private func leadingGap(plotW: CGFloat, plotH: CGFloat) -> some View {
        let now = Date()
        let window = selectedRange.seconds

        guard let first = points.first else {
            return AnyView(
                Rectangle().fill(Color.gray.opacity(0.08))
                    .frame(width: plotW, height: plotH)
            )
        }

        let age = now.timeIntervalSince(first.timestamp)
        let x = CGFloat((1 - age / window) * Double(plotW))

        if x > 1 {
            return AnyView(
                Rectangle().fill(Color.gray.opacity(0.08))
                    .frame(width: x, height: plotH)
            )
        }
        return AnyView(EmptyView())
    }

    // MARK: - Grid

    private func gridLines(plotW: CGFloat, plotH: CGFloat, wMin: Double, wMax: Double) -> some View {
        let range = wMax - wMin
        return ZStack {
            Path { path in
                for frac in [0.25, 0.5, 0.75] {
                    let y = plotH * CGFloat(frac)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: plotW, y: y))
                }
            }
            .stroke(Color.white.opacity(0.05), lineWidth: 0.5)

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

    // MARK: - Watt axis auto-scale

    private var wattAxisRange: (min: Double, max: Double) {
        var allMax: Double = 0
        var allMin: Double = 0

        for p in points {
            let vals = [p.solarWatts, p.batteryWatts, p.consumerWatts].compactMap { $0 }
            if let mx = vals.max() { allMax = max(allMax, mx) }
            if let mn = vals.min() { allMin = min(allMin, mn) }
        }

        if allMax < 50 { allMax = 50 }

        let posSteps: [Double] = [50, 100, 200, 300, 500, 750, 1000, 1500, 2000, 3000, 5000, 10000]
        let niceMax = posSteps.first { $0 >= allMax * 1.1 } ?? allMax * 1.2

        let niceMin: Double
        if allMin >= 0 {
            niceMin = 0
        } else {
            let absMin = abs(allMin) * 1.1
            niceMin = -(posSteps.first { $0 >= absMin } ?? absMin)
        }

        return (min: niceMin, max: niceMax)
    }

    private func wAxisLabels(_ range: (min: Double, max: Double)) -> [String] {
        if range.min >= 0 {
            return [formatAxisW(range.max), formatAxisW(range.max * 0.5), "0"]
        }
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

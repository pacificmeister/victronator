import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var deviceManager: DeviceManager

    private var isLandscape: Bool {
        UIScreen.main.bounds.width > UIScreen.main.bounds.height
    }

    var body: some View {
        NavigationView {
            GeometryReader { geo in
                let safeH = geo.size.height
                let safeW = geo.size.width

                if isLandscape {
                    landscapeLayout(width: safeW, height: safeH)
                } else {
                    portraitLayout(width: safeW, height: safeH)
                }
            }
            .background(VTheme.pageBG.ignoresSafeArea())
            .navigationTitle("Victronator")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Landscape: flow left, chart right, full height

    private func landscapeLayout(width: CGFloat, height: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 8) {
                StatusBannerView()
                EnergyFlowView(
                    metrics: deviceManager.metrics,
                    availableHeight: height - 40 // minus status banner
                )
            }
            .frame(width: (width - 32) * 0.45)

            VStack {
                if !deviceManager.dataHistory.points.isEmpty {
                    ChartView(points: deviceManager.dataHistory.points,
                              chartHeight: height - 16)
                } else {
                    chartPlaceholder
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - Portrait: flow on top, chart below, fill screen

    private func portraitLayout(width: CGFloat, height: CGFloat) -> some View {
        let flowH = height * 0.5
        let chartH = height * 0.42

        return VStack(spacing: 8) {
            StatusBannerView()

            EnergyFlowView(
                metrics: deviceManager.metrics,
                availableHeight: flowH
            )
            .padding(.horizontal)

            if !deviceManager.dataHistory.points.isEmpty {
                ChartView(points: deviceManager.dataHistory.points,
                          chartHeight: chartH)
                    .padding(.horizontal)
            } else {
                chartPlaceholder
                    .padding(.horizontal)
            }
        }
    }

    private var chartPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 28))
                .foregroundColor(VTheme.gray5.opacity(0.4))
            Text("Recording data...")
                .font(.system(size: 12))
                .foregroundColor(VTheme.gray5.opacity(0.6))
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: VTheme.cornerRadius)
                .fill(VTheme.widgetBG)
        )
    }
}

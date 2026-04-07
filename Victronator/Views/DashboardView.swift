import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var deviceManager: DeviceManager

    private var isLandscape: Bool {
        UIScreen.main.bounds.width > UIScreen.main.bounds.height
    }

    var body: some View {
        NavigationView {
            Group {
                if isLandscape {
                    landscapeLayout
                } else {
                    portraitLayout
                }
            }
            .background(VTheme.pageBG.ignoresSafeArea())
            .navigationTitle("Victronator")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }

    private var landscapeLayout: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 8) {
                StatusBannerView()
                EnergyFlowView(metrics: deviceManager.metrics)
            }
            .frame(maxWidth: .infinity)

            VStack {
                if !deviceManager.dataHistory.points.isEmpty {
                    ChartView(points: deviceManager.dataHistory.points)
                } else {
                    chartPlaceholder
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(12)
    }

    private var portraitLayout: some View {
        ScrollView {
            VStack(spacing: 16) {
                StatusBannerView()

                EnergyFlowView(metrics: deviceManager.metrics)
                    .padding(.horizontal)

                if !deviceManager.dataHistory.points.isEmpty {
                    ChartView(points: deviceManager.dataHistory.points)
                        .padding(.horizontal)
                } else {
                    chartPlaceholder
                        .padding(.horizontal)
                }

                Spacer(minLength: 20)
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

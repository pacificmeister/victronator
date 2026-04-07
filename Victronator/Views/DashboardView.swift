import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @Environment(\.horizontalSizeClass) var hSizeClass
    @Environment(\.verticalSizeClass) var vSizeClass

    /// Landscape on iPad: horizontal regular + vertical compact/regular in landscape
    private var isLandscape: Bool {
        // On iPad in landscape, both size classes are regular but width > height
        // Use UIScreen to detect actual orientation
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

    // MARK: - Landscape: flow left, chart right

    private var landscapeLayout: some View {
        HStack(spacing: 16) {
            VStack(spacing: 12) {
                StatusBannerView()
                EnergyFlowView(metrics: deviceManager.metrics)
                Spacer()
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

    // MARK: - Portrait: flow on top, chart below

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
            Text("Chart will appear as history builds up")
                .font(.system(size: 10))
                .foregroundColor(VTheme.gray5.opacity(0.4))
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: VTheme.cornerRadius)
                .fill(VTheme.widgetBG)
                .overlay(
                    RoundedRectangle(cornerRadius: VTheme.cornerRadius)
                        .stroke(VTheme.blue.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

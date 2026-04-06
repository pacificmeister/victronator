import SwiftUI

@main
struct VictronatorApp: App {
    @StateObject private var deviceManager = DeviceManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deviceManager)
                .environmentObject(deviceManager.keyStore)
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "gauge.with.dots.needle.bottom.50percent")
                }

            SettingsView()
                .tabItem {
                    Label("Devices", systemImage: "antenna.radiowaves.left.and.right")
                }
        }
    }
}

import SwiftUI
import UIKit

@main
struct VictronatorApp: App {
    @StateObject private var deviceManager = DeviceManager()

    init() {
        // Keep screen on (dashboard mode)
        UIApplication.shared.isIdleTimerDisabled = true

        // Dark navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        // Dark tab bar
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(white: 0.05, alpha: 1)
        UITabBar.appearance().standardAppearance = tabAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deviceManager)
                .environmentObject(deviceManager.keyStore)
                .preferredColorScheme(.dark)
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
        .accentColor(.orange)
    }
}

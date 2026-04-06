import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var keyStore: KeyStore

    var body: some View {
        NavigationView {
            List {
                if deviceManager.devices.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No Victron devices found")
                                .font(.headline)
                            Text("Make sure your Victron devices are nearby and have Instant Readout enabled in VictronConnect.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                } else {
                    Section("Discovered Devices") {
                        ForEach(deviceManager.sortedDevices) { device in
                            NavigationLink(destination: DeviceKeyEntryView(device: device)) {
                                DeviceRow(device: device)
                            }
                        }
                    }
                }

                Section("About") {
                    HStack {
                        Text("How to get encryption keys")
                            .font(.subheadline)
                    }
                    Text("In VictronConnect, go to your device → Settings → Product Info → \"Instant Readout via Bluetooth\" → tap Show next to the encryption key.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Devices")
        }
        .navigationViewStyle(.stack)
    }
}

struct DeviceRow: View {
    @ObservedObject var device: VictronDevice

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(device.deviceTypeName)
                    .font(.headline)
                Text("Model: 0x\(String(format: "%04X", device.modelId))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if device.hasKey {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Text("Needs Key")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            // Signal strength indicator
            signalIcon(rssi: device.rssi)
        }
    }

    private func signalIcon(rssi: Int) -> some View {
        let iconName: String
        if rssi > -50 { iconName = "wifi" }
        else if rssi > -70 { iconName = "wifi" }
        else if rssi > -90 { iconName = "wifi" }
        else { iconName = "wifi.slash" }
        let color: Color = rssi > -70 ? .green : rssi > -90 ? .yellow : .red
        return Image(systemName: iconName)
            .foregroundColor(color)
    }
}

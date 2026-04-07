import SwiftUI
import CoreBluetooth

struct StatusBannerView: View {
    @EnvironmentObject var deviceManager: DeviceManager

    var body: some View {
        HStack(spacing: 8) {
            statusIcon
            Text(statusText)
                .font(.system(size: 11))
                .foregroundColor(VTheme.gray5)
            Spacer()
            if let time = deviceManager.lastUpdateTime {
                Text(timeAgo(time))
                    .font(.system(size: 10))
                    .foregroundColor(VTheme.gray5.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 5 { return "just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        return "\(seconds / 60)m ago"
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch deviceManager.scanner.bluetoothState {
        case .poweredOn:
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundColor(deviceManager.scanner.isScanning ? VTheme.green : VTheme.orange)
                .font(.system(size: 12))
        case .poweredOff:
            Image(systemName: "bluetooth")
                .foregroundColor(VTheme.red)
                .font(.system(size: 12))
        default:
            Image(systemName: "questionmark.circle")
                .foregroundColor(VTheme.gray5)
                .font(.system(size: 12))
        }
    }

    private var statusText: String {
        switch deviceManager.scanner.bluetoothState {
        case .poweredOn:
            let count = deviceManager.devices.count
            if count == 0 { return "Scanning..." }
            let configured = deviceManager.devices.values.filter(\.hasKey).count
            return "\(count) device\(count == 1 ? "" : "s"), \(configured) configured"
        case .poweredOff:
            return "Bluetooth off"
        case .unauthorized:
            return "Bluetooth access denied"
        case .unsupported:
            return "BLE not supported"
        default:
            return "Initializing..."
        }
    }
}

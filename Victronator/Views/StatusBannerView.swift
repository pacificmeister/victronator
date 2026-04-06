import SwiftUI
import CoreBluetooth

struct StatusBannerView: View {
    @EnvironmentObject var deviceManager: DeviceManager

    var body: some View {
        HStack(spacing: 8) {
            statusIcon
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            if let time = deviceManager.lastUpdateTime {
                Text("Updated \(timeAgo(time))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch deviceManager.scanner.bluetoothState {
        case .poweredOn:
            if deviceManager.scanner.isScanning {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.yellow)
            }
        case .poweredOff:
            Image(systemName: "bluetooth")
                .foregroundColor(.red)
        default:
            Image(systemName: "questionmark.circle")
                .foregroundColor(.gray)
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 5 { return "just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        return "\(seconds / 60)m ago"
    }

    private var statusText: String {
        switch deviceManager.scanner.bluetoothState {
        case .poweredOn:
            let count = deviceManager.devices.count
            if count == 0 {
                return "Scanning for Victron devices..."
            }
            let configured = deviceManager.devices.values.filter(\.hasKey).count
            return "\(count) device\(count == 1 ? "" : "s") found, \(configured) configured"
        case .poweredOff:
            return "Bluetooth is off. Enable it in Settings."
        case .unauthorized:
            return "Bluetooth access denied. Check app permissions."
        case .unsupported:
            return "Bluetooth LE not supported on this device."
        default:
            return "Initializing Bluetooth..."
        }
    }
}

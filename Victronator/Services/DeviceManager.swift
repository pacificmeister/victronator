import Foundation
import Combine

/// Orchestrates BLE scanning, decryption, parsing, and dashboard metrics.
@MainActor
class DeviceManager: ObservableObject {
    @Published var devices: [UUID: VictronDevice] = [:]
    @Published var metrics = DashboardMetrics.empty
    @Published var lastUpdateTime: Date?

    let scanner = BLEScanner()
    let keyStore = KeyStore.shared

    private var cancellables = Set<AnyCancellable>()

    init() {
        scanner.advertisementReceived
            .receive(on: DispatchQueue.main)
            .sink { [weak self] advertisement, rssi in
                self?.processAdvertisement(advertisement, rssi: rssi)
            }
            .store(in: &cancellables)
    }

    /// Process an incoming Victron BLE advertisement.
    private func processAdvertisement(_ adv: VictronAdvertisement, rssi: Int) {
        // Update or create device entry
        let device: VictronDevice
        if let existing = devices[adv.peripheralId] {
            device = existing
            device.lastSeen = Date()
            device.rssi = rssi
        } else {
            device = VictronDevice(
                id: adv.peripheralId,
                modelId: adv.modelId,
                readoutType: adv.readoutType,
                rssi: rssi
            )
            devices[adv.peripheralId] = device
        }

        // Try to decrypt and parse if we have a key
        guard let key = keyStore.key(for: adv.peripheralId) else { return }

        guard let decrypted = try? VictronDecryptor.decrypt(
            encryptedPayload: adv.encryptedPayload,
            key: key,
            iv: adv.iv
        ) else { return }

        // Parse based on device type
        switch adv.deviceType {
        case .batteryMonitor:
            if let reading = SmartShuntParser.parse(data: decrypted) {
                device.lastReading = .smartShunt(reading)
                metrics.stateOfCharge = reading.stateOfCharge
                metrics.batteryPowerWatts = reading.batteryPowerWatts
                metrics.batteryVoltage = reading.batteryVoltage
            }

        case .solarCharger:
            if let reading = SmartSolarParser.parse(data: decrypted) {
                device.lastReading = .smartSolar(reading)
                metrics.solarPowerWatts = reading.solarPower.map(Double.init)
                metrics.chargeState = reading.chargeStateDescription
                metrics.yieldToday = reading.yieldToday
            }

        case .inverter:
            if let reading = InverterParser.parse(data: decrypted) {
                device.lastReading = .inverter(reading)
                metrics.inverterPowerVA = reading.acApparentPower.map(Double.init)
                metrics.acVoltage = reading.acVoltage
                metrics.inverterState = reading.deviceStateDescription
            }

        default:
            break // Unsupported device type
        }

        lastUpdateTime = Date()
        objectWillChange.send()
    }

    /// Sorted list of discovered devices.
    var sortedDevices: [VictronDevice] {
        devices.values.sorted { $0.deviceTypeName < $1.deviceTypeName }
    }
}

import Foundation
import CoreBluetooth
import Combine

/// Scans for Victron BLE advertisements using CoreBluetooth.
/// No connection is made - we only read manufacturer-specific advertisement data.
class BLEScanner: NSObject, ObservableObject {
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var isScanning = false

    /// Fires whenever a Victron advertisement is received.
    let advertisementReceived = PassthroughSubject<(VictronAdvertisement, Int), Never>()

    private var centralManager: CBCentralManager!

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        // Scan for all peripherals; filter by manufacturer ID in the delegate.
        // allowDuplicates = true is essential to receive repeated advertisements.
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        isScanning = true
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }
}

extension BLEScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        if central.state == .poweredOn {
            startScanning()
        } else {
            isScanning = false
        }
    }

    func centralManager(_ central: CBCentralManager,
                         didDiscover peripheral: CBPeripheral,
                         advertisementData: [String: Any],
                         rssi RSSI: NSNumber) {
        guard let mfgData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data else { return }

        // Quick check for Victron manufacturer ID
        guard mfgData.count >= 2,
              mfgData[0] == VictronConstants.manufacturerIdBytes[0],
              mfgData[1] == VictronConstants.manufacturerIdBytes[1] else { return }

        guard let advertisement = VictronAdvertisement(
            rawManufacturerData: mfgData,
            peripheralId: peripheral.identifier
        ) else { return }

        advertisementReceived.send((advertisement, RSSI.intValue))
    }
}

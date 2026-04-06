import Foundation

/// Represents a discovered Victron BLE device.
class VictronDevice: Identifiable, ObservableObject {
    let id: UUID // CoreBluetooth peripheral identifier
    var modelId: UInt16
    var readoutType: UInt8
    @Published var name: String
    @Published var lastSeen: Date
    @Published var rssi: Int
    @Published var lastReading: DeviceReading?

    init(id: UUID, modelId: UInt16, readoutType: UInt8, name: String = "Unknown",
         rssi: Int = 0, lastSeen: Date = Date()) {
        self.id = id
        self.modelId = modelId
        self.readoutType = readoutType
        self.name = name
        self.rssi = rssi
        self.lastSeen = lastSeen
    }

    var deviceTypeName: String {
        switch VictronConstants.ReadoutType(rawValue: readoutType) {
        case .solarCharger: return "SmartSolar"
        case .batteryMonitor: return "SmartShunt"
        case .inverter: return "Inverter"
        case .dcDcConverter: return "DC-DC"
        case .smartLithium: return "Smart Lithium"
        case .acCharger: return "AC Charger"
        default: return "Victron Device"
        }
    }

    var hasKey: Bool {
        KeyStore.shared.hasKey(for: id)
    }
}

/// A decoded reading from a Victron device.
enum DeviceReading {
    case smartShunt(SmartShuntReading)
    case smartSolar(SmartSolarReading)
    case inverter(InverterReading)
}

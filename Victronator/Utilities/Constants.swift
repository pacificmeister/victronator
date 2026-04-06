import Foundation

enum VictronConstants {
    /// Victron Energy BLE manufacturer ID (Bluetooth SIG assigned)
    static let manufacturerId: UInt16 = 0x02E1
    /// Manufacturer ID bytes as they appear in advertisement data (little-endian)
    static let manufacturerIdBytes: [UInt8] = [0xE1, 0x02]

    /// Readout type identifiers
    enum ReadoutType: UInt8 {
        case solarCharger = 0x01
        case batteryMonitor = 0x02
        case inverter = 0x03
        case dcDcConverter = 0x04
        case smartLithium = 0x05
        case inverterRS = 0x06
        case gxDevice = 0x07
        case acCharger = 0x08
        case smartBatteryProtect = 0x09
        case lynxSmartBMS = 0x0A
        case multiRS = 0x0B
        case veBus = 0x0C
        case dcEnergyMeter = 0x0D
        case orionXS = 0x0F
    }

    /// Null sentinel values for SmartShunt fields
    enum SmartShuntNull {
        static let timeToGo: UInt32 = 0xFFFF
        static let batteryVoltage: UInt32 = 0x7FFF
        static let batteryCurrent: UInt32 = 0x3FFFFF
        static let consumedAh: UInt32 = 0xFFFFF
        static let stateOfCharge: UInt32 = 0x3FF
    }

    /// Null sentinel values for SmartSolar fields
    enum SmartSolarNull {
        static let chargeState: UInt32 = 0xFF
        static let chargerError: UInt32 = 0xFF
        static let batteryVoltage: UInt32 = 0x7FFF
        static let batteryChargingCurrent: UInt32 = 0x7FFF
        static let yieldToday: UInt32 = 0xFFFF
        static let solarPower: UInt32 = 0xFFFF
        static let externalDeviceLoad: UInt32 = 0x1FF
    }

    /// Solar charger operation modes
    enum ChargeState: UInt8, CustomStringConvertible {
        case off = 0
        case lowPower = 1
        case fault = 2
        case bulk = 3
        case absorption = 4
        case float = 5
        case storage = 6
        case equalize = 7
        case inverting = 9
        case powerSupply = 11
        case startingUp = 245
        case repeatedAbsorption = 246
        case recondition = 247
        case externalControl = 252

        var description: String {
            switch self {
            case .off: return "Off"
            case .lowPower: return "Low Power"
            case .fault: return "Fault"
            case .bulk: return "Bulk"
            case .absorption: return "Absorption"
            case .float: return "Float"
            case .storage: return "Storage"
            case .equalize: return "Equalize"
            case .inverting: return "Inverting"
            case .powerSupply: return "Power Supply"
            case .startingUp: return "Starting Up"
            case .repeatedAbsorption: return "Repeated Absorption"
            case .recondition: return "Recondition"
            case .externalControl: return "External Control"
            }
        }
    }
}

import Foundation

/// Decoded data from a Victron Inverter/Multiplus BLE advertisement.
struct InverterReading {
    let deviceState: UInt8          // 0=Off, 9=Inverting, etc.
    let alarmReason: UInt16         // Alarm bitmask
    let batteryVoltage: Double?     // Volts
    let acApparentPower: UInt16?    // VA (volt-amps)
    let acVoltage: Double?          // Volts AC output
    let acCurrent: Double?          // Amps AC output

    var deviceStateDescription: String {
        switch deviceState {
        case 0: return "Off"
        case 1: return "Low Power"
        case 2: return "Fault"
        case 9: return "Inverting"
        default: return "Unknown (\(deviceState))"
        }
    }
}

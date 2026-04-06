import SwiftUI

struct DeviceKeyEntryView: View {
    @ObservedObject var device: VictronDevice
    @EnvironmentObject var keyStore: KeyStore
    @State private var keyInput: String = ""
    @State private var showError = false
    @State private var saved = false

    var body: some View {
        Form {
            Section(header: Text("Device Info")) {
                InfoRow("Type", device.deviceTypeName)
                InfoRow("Model ID", "0x\(String(format: "%04X", device.modelId))")
                InfoRow("Signal", "\(device.rssi) dBm")
            }

            Section(header: Text("Encryption Key")) {
                TextField("Enter 32-character hex key", text: $keyInput)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: keyInput) { _ in
                        showError = false
                        saved = false
                    }

                if showError {
                    Text("Invalid key. Must be exactly 32 hex characters (0-9, a-f).")
                        .font(.caption)
                        .foregroundColor(.red)
                }

                if saved {
                    Label("Key saved successfully", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }

                Button("Save Key") {
                    if keyStore.setKey(hexString: keyInput, for: device.id) {
                        saved = true
                        showError = false
                    } else {
                        showError = true
                        saved = false
                    }
                }
                .disabled(keyInput.isEmpty)
            }

            if device.hasKey {
                Section {
                    Button(role: .destructive) {
                        keyStore.removeKey(for: device.id)
                        keyInput = ""
                        saved = false
                    } label: {
                        Text("Remove Key")
                    }
                }
            }

            if let reading = device.lastReading {
                Section(header: Text("Latest Reading")) {
                    switch reading {
                    case .smartShunt(let r):
                        if let soc = r.stateOfCharge {
                            InfoRow("SOC", "\(String(format: "%.1f", soc))%")
                        }
                        if let v = r.batteryVoltage {
                            InfoRow("Voltage", "\(String(format: "%.2f", v)) V")
                        }
                        if let a = r.batteryCurrent {
                            InfoRow("Current", "\(String(format: "%.2f", a)) A")
                        }
                        if let w = r.batteryPowerWatts {
                            InfoRow("Power", "\(String(format: "%.0f", w)) W")
                        }
                    case .smartSolar(let r):
                        if let w = r.solarPower {
                            InfoRow("Solar Power", "\(w) W")
                        }
                        InfoRow("Charge State", r.chargeStateDescription)
                        if let v = r.batteryVoltage {
                            InfoRow("Battery", "\(String(format: "%.2f", v)) V")
                        }
                        if let y = r.yieldToday {
                            InfoRow("Yield Today", "\(String(format: "%.0f", y)) Wh")
                        }
                    case .inverter(let r):
                        InfoRow("State", r.deviceStateDescription)
                        if let va = r.acApparentPower {
                            InfoRow("AC Power", "\(va) VA")
                        }
                        if let v = r.acVoltage {
                            InfoRow("AC Voltage", "\(String(format: "%.1f", v)) V")
                        }
                        if let a = r.acCurrent {
                            InfoRow("AC Current", "\(String(format: "%.1f", a)) A")
                        }
                        if let v = r.batteryVoltage {
                            InfoRow("Battery", "\(String(format: "%.2f", v)) V")
                        }
                    }
                }
            }
        }
        .navigationTitle(device.deviceTypeName)
        .onAppear {
            if let hex = keyStore.keys[device.id.uuidString] {
                keyInput = hex
            }
        }
    }
}

/// Simple label-value row compatible with iOS 15.
private struct InfoRow: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

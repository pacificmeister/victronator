import SwiftUI

struct DeviceKeyEntryView: View {
    @ObservedObject var device: VictronDevice
    @EnvironmentObject var keyStore: KeyStore
    @State private var keyInput: String = ""
    @State private var showError = false
    @State private var saved = false

    var body: some View {
        Form {
            Section("Device Info") {
                LabeledContent("Type", value: device.deviceTypeName)
                LabeledContent("Model ID", value: "0x\(String(format: "%04X", device.modelId))")
                LabeledContent("Signal", value: "\(device.rssi) dBm")
                LabeledContent("Last Seen", value: device.lastSeen, format: .relative(presentation: .named))
            }

            Section("Encryption Key") {
                TextField("Enter 32-character hex key", text: $keyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
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
                    Button("Remove Key", role: .destructive) {
                        keyStore.removeKey(for: device.id)
                        keyInput = ""
                        saved = false
                    }
                }
            }

            if let reading = device.lastReading {
                Section("Latest Reading") {
                    switch reading {
                    case .smartShunt(let r):
                        if let soc = r.stateOfCharge {
                            LabeledContent("SOC", value: "\(String(format: "%.1f", soc))%")
                        }
                        if let v = r.batteryVoltage {
                            LabeledContent("Voltage", value: "\(String(format: "%.2f", v)) V")
                        }
                        if let a = r.batteryCurrent {
                            LabeledContent("Current", value: "\(String(format: "%.2f", a)) A")
                        }
                        if let w = r.batteryPowerWatts {
                            LabeledContent("Power", value: "\(String(format: "%.0f", w)) W")
                        }
                    case .smartSolar(let r):
                        if let w = r.solarPower {
                            LabeledContent("Solar Power", value: "\(w) W")
                        }
                        LabeledContent("Charge State", value: r.chargeStateDescription)
                        if let v = r.batteryVoltage {
                            LabeledContent("Battery", value: "\(String(format: "%.2f", v)) V")
                        }
                        if let y = r.yieldToday {
                            LabeledContent("Yield Today", value: "\(String(format: "%.0f", y)) Wh")
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

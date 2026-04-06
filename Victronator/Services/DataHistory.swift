import Foundation

/// A single snapshot of all metrics at a point in time.
struct DataPoint: Codable {
    let timestamp: Date
    let soc: Double?
    let solarWatts: Double?
    let batteryWatts: Double?
    let consumerWatts: Double?
    let inverterVA: Double?
    let acVoltage: Double?
}

/// Records and persists 24 hours of metric history.
class DataHistory: ObservableObject {
    @Published private(set) var points: [DataPoint] = []

    private let maxAge: TimeInterval = 24 * 60 * 60 // 24 hours
    private let sampleInterval: TimeInterval = 10    // Record every 10 seconds
    private var lastSample: Date = .distantPast
    private let storageKey = "victronator.data_history"

    init() {
        load()
    }

    /// Record a new data point if enough time has passed since the last one.
    func record(metrics: DashboardMetrics) {
        let now = Date()
        guard now.timeIntervalSince(lastSample) >= sampleInterval else { return }

        // Detect shore power: if battery is charging more than solar provides
        let estimatedShore = estimateConsumerPower(metrics: metrics)

        let point = DataPoint(
            timestamp: now,
            soc: metrics.stateOfCharge,
            solarWatts: metrics.solarPowerWatts,
            batteryWatts: metrics.batteryPowerWatts,
            consumerWatts: estimatedShore.consumerWatts,
            inverterVA: metrics.inverterPowerVA,
            acVoltage: metrics.acVoltage
        )

        points.append(point)
        lastSample = now
        pruneOldData()

        // Save periodically (every 60 samples = ~10 minutes)
        if points.count % 60 == 0 {
            save()
        }
    }

    /// Estimate consumer power and detect shore power.
    /// Consumer = Solar - Battery (when battery positive = charging)
    /// If battery is charging AND solar < battery charging rate, shore power likely.
    func estimateConsumerPower(metrics: DashboardMetrics) -> (consumerWatts: Double?, shorePowerDetected: Bool) {
        guard let battery = metrics.batteryPowerWatts else {
            return (metrics.inverterPowerVA, false)
        }
        let solar = metrics.solarPowerWatts ?? 0

        // Consumer = solar production - battery power (positive battery = charging)
        // If inverter VA is available, prefer that as consumer indicator
        let consumer: Double
        if let inverterVA = metrics.inverterPowerVA, inverterVA > 0 {
            consumer = inverterVA
        } else {
            consumer = max(0, solar - battery)
        }

        // Shore power detection:
        // If battery is charging (positive) and solar alone can't explain
        // the charging + consumption, shore/generator power is present.
        let shorePower = battery > 0 && solar < (battery + consumer * 0.8)
        return (consumer, shorePower)
    }

    /// Whether shore/generator power appears to be active based on recent data.
    var isShoreDetected: Bool {
        guard points.count >= 3 else { return false }
        let recent = points.suffix(3)
        return recent.allSatisfy { p in
            guard let battery = p.batteryWatts, battery > 50 else { return false }
            let solar = p.solarWatts ?? 0
            let consumer = p.consumerWatts ?? 0
            return solar < (battery + consumer * 0.8)
        }
    }

    private func pruneOldData() {
        let cutoff = Date().addingTimeInterval(-maxAge)
        points.removeAll { $0.timestamp < cutoff }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(points) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([DataPoint].self, from: data) else { return }
        points = decoded
        pruneOldData()
    }
}

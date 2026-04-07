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

/// Records and persists up to 7 days of metric history.
/// Last 24h at full resolution (10s), older data downsampled to 5min averages.
class DataHistory: ObservableObject {
    /// Full-resolution points (last 24h, 10s interval)
    @Published private(set) var recentPoints: [DataPoint] = []
    /// Downsampled points (24h-7d, 5min averages)
    @Published private(set) var archivedPoints: [DataPoint] = []

    private let maxRecentAge: TimeInterval = 24 * 60 * 60       // 24 hours
    private let maxArchiveAge: TimeInterval = 7 * 24 * 60 * 60  // 7 days
    private let sampleInterval: TimeInterval = 10
    private let archiveInterval: TimeInterval = 5 * 60           // 5 min buckets
    private var lastSample: Date = .distantPast
    private var lastArchiveRun: Date = .distantPast

    private let recentKey = "victronator.data_recent"
    private let archiveKey = "victronator.data_archive"

    /// All points combined (archived + recent), sorted by time.
    var allPoints: [DataPoint] {
        archivedPoints + recentPoints
    }

    init() {
        load()
    }

    /// Record a new data point if enough time has passed.
    func record(metrics: DashboardMetrics) {
        let now = Date()
        guard now.timeIntervalSince(lastSample) >= sampleInterval else { return }

        let estimated = estimateConsumerPower(metrics: metrics)

        let point = DataPoint(
            timestamp: now,
            soc: metrics.stateOfCharge,
            solarWatts: metrics.solarPowerWatts,
            batteryWatts: metrics.batteryPowerWatts,
            consumerWatts: estimated.consumerWatts,
            inverterVA: metrics.inverterPowerVA,
            acVoltage: metrics.acVoltage
        )

        recentPoints.append(point)
        lastSample = now

        // Prune and downsample periodically (every 5 min)
        if now.timeIntervalSince(lastArchiveRun) > archiveInterval {
            pruneAndArchive()
            lastArchiveRun = now
        }

        // Save periodically (every 60 samples = ~10 minutes)
        if recentPoints.count % 60 == 0 {
            save()
        }
    }

    /// Estimate consumer power and detect shore power.
    func estimateConsumerPower(metrics: DashboardMetrics) -> (consumerWatts: Double?, shorePowerDetected: Bool) {
        guard let battery = metrics.batteryPowerWatts else {
            return (metrics.inverterPowerVA, false)
        }
        let solar = metrics.solarPowerWatts ?? 0

        let consumer: Double
        if let inverterVA = metrics.inverterPowerVA, inverterVA > 0 {
            consumer = inverterVA
        } else {
            consumer = max(0, solar - battery)
        }

        let shorePower = battery > 0 && solar < (battery + consumer * 0.8)
        return (consumer, shorePower)
    }

    /// Whether shore/generator power appears to be active based on recent data.
    var isShoreDetected: Bool {
        guard recentPoints.count >= 3 else { return false }
        let recent = recentPoints.suffix(3)
        return recent.allSatisfy { p in
            guard let battery = p.batteryWatts, battery > 50 else { return false }
            let solar = p.solarWatts ?? 0
            let consumer = p.consumerWatts ?? 0
            return solar < (battery + consumer * 0.8)
        }
    }

    /// Get points for a specific time range.
    func points(for range: ChartRange) -> [DataPoint] {
        let cutoff = Date().addingTimeInterval(-range.seconds)
        return allPoints.filter { $0.timestamp >= cutoff }
    }

    // MARK: - Prune & Downsample

    private func pruneAndArchive() {
        let now = Date()
        let recentCutoff = now.addingTimeInterval(-maxRecentAge)
        let archiveCutoff = now.addingTimeInterval(-maxArchiveAge)

        // Move points older than 24h from recent to archive (downsampled)
        let oldPoints = recentPoints.filter { $0.timestamp < recentCutoff }
        recentPoints.removeAll { $0.timestamp < recentCutoff }

        if !oldPoints.isEmpty {
            let downsampled = downsample(oldPoints, bucketSize: archiveInterval)
            archivedPoints.append(contentsOf: downsampled)
        }

        // Prune archive older than 7 days
        archivedPoints.removeAll { $0.timestamp < archiveCutoff }
    }

    /// Average points into fixed-size time buckets.
    private func downsample(_ points: [DataPoint], bucketSize: TimeInterval) -> [DataPoint] {
        guard let first = points.first else { return [] }

        var result: [DataPoint] = []
        var bucketStart = first.timestamp
        var bucket: [DataPoint] = []

        for p in points {
            if p.timestamp.timeIntervalSince(bucketStart) < bucketSize {
                bucket.append(p)
            } else {
                if !bucket.isEmpty {
                    result.append(averageBucket(bucket))
                }
                bucketStart = p.timestamp
                bucket = [p]
            }
        }
        if !bucket.isEmpty {
            result.append(averageBucket(bucket))
        }

        return result
    }

    private func averageBucket(_ bucket: [DataPoint]) -> DataPoint {
        let count = Double(bucket.count)
        let midTimestamp = bucket[bucket.count / 2].timestamp

        func avg(_ keyPath: KeyPath<DataPoint, Double?>) -> Double? {
            let vals = bucket.compactMap { $0[keyPath: keyPath] }
            guard !vals.isEmpty else { return nil }
            return vals.reduce(0, +) / Double(vals.count)
        }

        return DataPoint(
            timestamp: midTimestamp,
            soc: avg(\.soc),
            solarWatts: avg(\.solarWatts),
            batteryWatts: avg(\.batteryWatts),
            consumerWatts: avg(\.consumerWatts),
            inverterVA: avg(\.inverterVA),
            acVoltage: avg(\.acVoltage)
        )
    }

    // MARK: - Persistence

    func save() {
        if let data = try? JSONEncoder().encode(recentPoints) {
            UserDefaults.standard.set(data, forKey: recentKey)
        }
        if let data = try? JSONEncoder().encode(archivedPoints) {
            UserDefaults.standard.set(data, forKey: archiveKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: recentKey),
           let decoded = try? JSONDecoder().decode([DataPoint].self, from: data) {
            recentPoints = decoded
        }
        if let data = UserDefaults.standard.data(forKey: archiveKey),
           let decoded = try? JSONDecoder().decode([DataPoint].self, from: data) {
            archivedPoints = decoded
        }
        // Run prune on load to clean up
        pruneAndArchive()
    }
}

// MARK: - Chart Time Range

enum ChartRange: String, CaseIterable {
    case hour1 = "1h"
    case hour12 = "12h"
    case hour24 = "24h"
    case week1 = "1w"

    var seconds: TimeInterval {
        switch self {
        case .hour1: return 3600
        case .hour12: return 12 * 3600
        case .hour24: return 24 * 3600
        case .week1: return 7 * 24 * 3600
        }
    }
}

import Foundation
import HealthKit

@Observable
final class HealthKitService {
    struct Metrics: Sendable {
        var heartRateBPM: Int?
        var oxygenPercent: Int?
        var respiratoryRate: Int?
        var fetchedAt: Date?
    }

    private let healthStore = HKHealthStore()
    var isAvailable = HKHealthStore.isHealthDataAvailable()
    var isAuthorized = false
    var isLoading = false
    var lastErrorMessage: String?
    var metrics = Metrics()

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let oxygen = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) {
            types.insert(oxygen)
        }
        if let respiratory = HKObjectType.quantityType(forIdentifier: .respiratoryRate) {
            types.insert(respiratory)
        }
        return types
    }

    func requestAuthorization() async -> Bool {
        guard isAvailable else {
            lastErrorMessage = "Health data is not available on this iPhone."
            return false
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            await refreshAuthorizationStatus()
            return isAuthorized
        } catch {
            lastErrorMessage = "Unable to connect to Apple Health: \(error.localizedDescription)"
            isAuthorized = false
            return false
        }
    }

    func refreshAuthorizationStatus() async {
        let statuses = readTypes.compactMap { type -> HKAuthorizationStatus? in
            guard let quantityType = type as? HKQuantityType else { return nil }
            return healthStore.authorizationStatus(for: quantityType)
        }
        isAuthorized = statuses.contains(.sharingAuthorized)
    }

    func refreshMetrics() async {
        guard isAvailable else {
            isAuthorized = false
            lastErrorMessage = "Health data is not available on this iPhone."
            return
        }
        isLoading = true
        defer { isLoading = false }

        await refreshAuthorizationStatus()
        guard isAuthorized else {
            lastErrorMessage = "Health access not granted. Connect from Settings."
            return
        }

        async let hr = latestHeartRateBPM()
        async let spo2 = latestOxygenSaturationPercent()
        async let rr = latestRespiratoryRate()
        let (heartRate, oxygen, respiratory) = await (hr, spo2, rr)
        metrics = Metrics(
            heartRateBPM: heartRate,
            oxygenPercent: oxygen,
            respiratoryRate: respiratory,
            fetchedAt: Date()
        )
    }

    private func latestHeartRateBPM() async -> Int? {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRate) else { return nil }
        guard let sample = await latestSample(for: type) else { return nil }
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        return Int(sample.quantity.doubleValue(for: bpmUnit).rounded())
    }

    private func latestOxygenSaturationPercent() async -> Int? {
        guard let type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) else { return nil }
        guard let sample = await latestSample(for: type) else { return nil }
        let percent = sample.quantity.doubleValue(for: .percent()) * 100
        return Int(percent.rounded())
    }

    private func latestRespiratoryRate() async -> Int? {
        guard let type = HKObjectType.quantityType(forIdentifier: .respiratoryRate) else { return nil }
        guard let sample = await latestSample(for: type) else { return nil }
        let unit = HKUnit.count().unitDivided(by: .minute())
        return Int(sample.quantity.doubleValue(for: unit).rounded())
    }

    private func latestSample(for quantityType: HKQuantityType) async -> HKQuantitySample? {
        await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if error != nil {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: samples?.first as? HKQuantitySample)
            }
            healthStore.execute(query)
        }
    }
}

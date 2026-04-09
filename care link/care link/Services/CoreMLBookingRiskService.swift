import Foundation

struct BookingRiskAssessment: Sendable {
    enum Level: String, Sendable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
    }

    let score: Double
    let level: Level
    let source: String

    var shortText: String {
        "\(level.rawValue) cancellation risk"
    }
}

@Observable
final class CoreMLBookingRiskService {
    private let modelProvider: CoreMLModelProviding
    private let modelName = "BookingRiskClassifier"
    private let outputKey = "riskScore"

    init(modelProvider: CoreMLModelProviding = DefaultCoreMLModelProvider()) {
        self.modelProvider = modelProvider
    }

    func assessRisk(
        booking: Booking,
        userHistory: [Booking]
    ) -> BookingRiskAssessment {
        let features = makeFeatures(booking: booking, userHistory: userHistory)
        if let mlScore = modelProvider.prediction(
            modelName: modelName,
            inputFeatures: features,
            outputKey: outputKey
        ) {
            return makeAssessment(score: clamp01(mlScore), source: "coreml")
        }

        let fallbackScore = fallbackRiskScore(features: features)
        return makeAssessment(score: fallbackScore, source: "fallback")
    }

    private func makeFeatures(booking: Booking, userHistory: [Booking]) -> [String: Double] {
        let totalCount = Double(userHistory.count)
        let cancelledCount = Double(userHistory.filter { $0.status == .cancelled }.count)
        let cancellationRate = totalCount > 0 ? cancelledCount / totalCount : 0
        let isWeekend = Calendar.current.isDateInWeekend(booking.date) ? 1.0 : 0.0
        let hour = Double(Calendar.current.component(.hour, from: booking.startTime))
        let shortNoticeHours = max(0, booking.startTime.timeIntervalSince(booking.createdAt) / 3600)

        return [
            "durationHours": booking.duration,
            "totalCost": booking.totalCost,
            "isCashPayment": booking.paymentMethod == .cash ? 1 : 0,
            "isWeekend": isWeekend,
            "startHour": hour,
            "hoursUntilStart": shortNoticeHours,
            "userPastBookings": totalCount,
            "userCancellationRate": cancellationRate
        ]
    }

    private func fallbackRiskScore(features: [String: Double]) -> Double {
        let cancelRate = features["userCancellationRate", default: 0]
        let isCash = features["isCashPayment", default: 0]
        let isWeekend = features["isWeekend", default: 0]
        let hoursUntilStart = features["hoursUntilStart", default: 24]
        let totalCost = features["totalCost", default: 0]

        var score = 0.08
        score += cancelRate * 0.55
        score += isCash * 0.1
        score += isWeekend * 0.08
        if hoursUntilStart < 12 { score += 0.14 }
        if hoursUntilStart < 4 { score += 0.08 }
        if totalCost > 250 { score += 0.06 }
        return clamp01(score)
    }

    private func makeAssessment(score: Double, source: String) -> BookingRiskAssessment {
        let level: BookingRiskAssessment.Level
        switch score {
        case ..<0.35: level = .low
        case ..<0.65: level = .medium
        default: level = .high
        }
        return BookingRiskAssessment(score: score, level: level, source: source)
    }

    private func clamp01(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

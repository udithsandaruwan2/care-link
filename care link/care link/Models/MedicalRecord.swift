import Foundation

struct MedicalRecord: Identifiable, Codable, Sendable {
    let id: String
    var patientId: String
    var patientName: String
    var caregiverId: String
    var caregiverName: String
    var title: String
    var recordDescription: String
    var recordType: RecordType
    var date: Date
    var notes: String
    var createdAt: Date

    enum RecordType: String, Codable, Sendable, CaseIterable {
        case vitals = "Vitals"
        case medication = "Medication"
        case note = "Note"
        case diagnosis = "Diagnosis"
        case labResult = "Lab Result"
        case procedure = "Procedure"

        var iconName: String {
            switch self {
            case .vitals: return "heart.text.clipboard.fill"
            case .medication: return "pills.fill"
            case .note: return "note.text"
            case .diagnosis: return "stethoscope"
            case .labResult: return "flask.fill"
            case .procedure: return "cross.case.fill"
            }
        }

        var colorHex: String {
            switch self {
            case .vitals: return "DC2626"
            case .medication: return "0066CC"
            case .note: return "64748B"
            case .diagnosis: return "7C3AED"
            case .labResult: return "0D9488"
            case .procedure: return "F59E0B"
            }
        }
    }
}

import Foundation

/// Single place for booking lifecycle rules (patient vs caregiver) and how they map to `connections`.
enum BookingStateMachine: Sendable {
    enum Actor: Sendable {
        case patient
        case caregiver
    }

    enum TransitionError: LocalizedError, Sendable {
        case bookingNotFound
        case forbidden
        case invalidTransition(from: Booking.BookingStatus, to: Booking.BookingStatus, actor: Actor)

        var errorDescription: String? {
            switch self {
            case .bookingNotFound:
                return "Booking could not be found."
            case .forbidden:
                return "You are not allowed to change this booking."
            case .invalidTransition(let from, let to, let actor):
                return "Cannot move booking from \(from.rawValue) to \(to.rawValue) as \(actor == .patient ? "patient" : "caregiver")."
            }
        }
    }

    /// Whether the signed-in user may act on this booking for the given role.
    static func callerMatches(actor: Actor, booking: Booking, callerUid: String) -> Bool {
        switch actor {
        case .patient:
            return booking.userId == callerUid
        case .caregiver:
            return booking.caregiverId == callerUid
        }
    }

    /// Allowed status changes from chat, dashboard, and patient cancel paths.
    static func canTransition(
        from current: Booking.BookingStatus,
        to next: Booking.BookingStatus,
        actor: Actor
    ) -> Bool {
        guard current != next else { return false }
        switch actor {
        case .patient:
            switch (current, next) {
            case (.awaitingCaregiver, .cancelled), (.pending, .cancelled), (.confirmed, .cancelled), (.inProgress, .cancelled):
                return true
            default:
                return false
            }
        case .caregiver:
            switch (current, next) {
            case (.awaitingCaregiver, .confirmed), (.pending, .confirmed):
                return true
            case (.awaitingCaregiver, .cancelled), (.pending, .cancelled):
                return true
            case (.confirmed, .inProgress):
                return true
            case (.confirmed, .completed), (.inProgress, .completed):
                return true
            default:
                return false
            }
        }
    }

    /// Patient-facing cancel affordance (UI + list filters).
    static func patientMayRequestCancel(status: Booking.BookingStatus) -> Bool {
        switch status {
        case .awaitingCaregiver, .pending, .confirmed, .inProgress:
            return true
        case .completed, .cancelled:
            return false
        }
    }

    /// Connection document side-effect for a successful Firestore status write.
    static func connectionStatusAfterTransition(
        from previous: Booking.BookingStatus,
        to next: Booking.BookingStatus,
        actor: Actor
    ) -> Connection.ConnectionStatus? {
        switch next {
        case .confirmed:
            guard actor == .caregiver else { return nil }
            guard previous == .awaitingCaregiver || previous == .pending else { return nil }
            return .approved
        case .cancelled:
            guard previous != .completed else { return nil }
            if previous == .awaitingCaregiver || previous == .pending || previous == .confirmed || previous == .inProgress {
                return .rejected
            }
            return nil
        default:
            return nil
        }
    }
}

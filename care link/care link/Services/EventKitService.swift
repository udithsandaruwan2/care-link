import Foundation
import EventKit

@Observable
final class EventKitService {
    private let eventStore = EKEventStore()
    var isAuthorized = false
    var errorMessage: String?

    func requestAccess() async {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            isAuthorized = granted
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addBookingToCalendar(booking: Booking) async -> Bool {
        guard isAuthorized else {
            await requestAccess()
            guard isAuthorized else { return false }
            return await addBookingToCalendar(booking: booking)
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = "CareLink: \(booking.caregiverName)"
        event.startDate = booking.startTime
        event.endDate = booking.endTime
        event.location = booking.address
        event.notes = """
        Caregiver: \(booking.caregiverName) (\(booking.caregiverSpecialty))
        Location: \(booking.location) - \(booking.address)
        Duration: \(booking.duration) hours
        Total: $\(String(format: "%.2f", booking.totalCost))
        """
        event.calendar = eventStore.defaultCalendarForNewEvents

        let alarm = EKAlarm(relativeOffset: -3600)
        event.addAlarm(alarm)

        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

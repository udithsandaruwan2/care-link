import Foundation
import FirebaseFirestore
import FirebaseFunctions

enum BookingFunctionsError: LocalizedError {
    case functionUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .functionUnavailable(let detail):
            return detail
        }
    }
}

/// Server-authoritative booking create and status updates via Cloud Functions.
enum BookingFunctionsService {
    /// Try default + common regions so app keeps working if function region drifts.
    private static let functionClients: [Functions] = [
        Functions.functions(),
        Functions.functions(region: "us-central1"),
        Functions.functions(region: "asia-south1"),
        Functions.functions(region: "asia-southeast1")
    ]

    static func createBookingRequest(_ booking: Booking) async throws {
        let bookingPayload = buildJSONSafeBookingPayload(booking)
        do {
            _ = try await callCallable(name: "createBookingRequest", data: [
                "booking": bookingPayload
            ])
        } catch {
            throw Self.mapFunctionsError(error)
        }
    }

    static func updateBookingStatus(bookingId: String, newStatus: Booking.BookingStatus) async throws {
        do {
            _ = try await callCallable(name: "updateBookingStatus", data: [
                "bookingId": bookingId,
                "newStatus": newStatus.rawValue
            ])
        } catch {
            throw Self.mapFunctionsError(error)
        }
    }

    private static func callCallable(name: String, data: [String: Any]) async throws -> HTTPSCallableResult {
        var lastError: Error?
        for client in functionClients {
            do {
                return try await client.httpsCallable(name).call(data)
            } catch {
                let ns = error as NSError
                if ns.domain == FunctionsErrorDomain,
                   FunctionsErrorCode(rawValue: ns.code) == .notFound {
                    lastError = error
                    continue
                }
                throw error
            }
        }
        throw lastError ?? BookingFunctionsError.functionUnavailable("Cloud Function `\(name)` was not found.")
    }

    /// Callable data must be JSON-serializable. Encode date fields as epoch milliseconds.
    private static func buildJSONSafeBookingPayload(_ booking: Booking) -> [String: Any] {
        func ms(_ date: Date) -> Int64 {
            Int64((date.timeIntervalSince1970 * 1000.0).rounded())
        }

        var payload: [String: Any] = [
            "id": booking.id,
            "userId": booking.userId,
            "patientName": booking.patientName,
            "caregiverId": booking.caregiverId,
            "caregiverName": booking.caregiverName,
            "caregiverSpecialty": booking.caregiverSpecialty,
            "caregiverImageURL": booking.caregiverImageURL,
            "caregiverRating": booking.caregiverRating,
            "date": ms(booking.date),
            "startTime": ms(booking.startTime),
            "endTime": ms(booking.endTime),
            "duration": booking.duration,
            "totalCost": booking.totalCost,
            "status": booking.status.rawValue,
            "location": booking.location,
            "address": booking.address,
            "paymentMethod": booking.paymentMethod.rawValue,
            "createdAt": ms(booking.createdAt)
        ]

        if let careRecipientId = booking.careRecipientId {
            payload["careRecipientId"] = careRecipientId
        }
        if let careRecipientRelation = booking.careRecipientRelation {
            payload["careRecipientRelation"] = careRecipientRelation
        }
        if let cancellationRequestedByUid = booking.cancellationRequestedByUid {
            payload["cancellationRequestedByUid"] = cancellationRequestedByUid
        }
        if let cancellationRequestedByRole = booking.cancellationRequestedByRole {
            payload["cancellationRequestedByRole"] = cancellationRequestedByRole
        }
        if let cancellationRequestedAt = booking.cancellationRequestedAt {
            payload["cancellationRequestedAt"] = ms(cancellationRequestedAt)
        }
        return payload
    }

    private static func mapFunctionsError(_ error: Error) -> Error {
        let ns = error as NSError
        if ns.domain == FunctionsErrorDomain {
            let code = FunctionsErrorCode(rawValue: ns.code) ?? .unknown
            if code == .notFound {
                return BookingFunctionsError.functionUnavailable(
                    "Booking backend is not deployed or region-mismatched (`\(ns.localizedDescription)`). Deploy functions and try again."
                )
            }
            let message = ns.localizedDescription
            return NSError(
                domain: "BookingFunctionsService",
                code: ns.code,
                userInfo: [NSLocalizedDescriptionKey: "\(code): \(message)"]
            )
        }
        return error
    }
}

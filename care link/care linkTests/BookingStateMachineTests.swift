import XCTest
@testable import care_link

/// Mirrors critical cases in `functions/src/bookingRules.test.ts`; keep Swift and server rules aligned.
final class BookingStateMachineTests: XCTestCase {

    func testPatientMayCancelFromActiveStates() {
        for status in [Booking.BookingStatus.awaitingCaregiver, .pending, .confirmed, .inProgress] {
            XCTAssertTrue(BookingStateMachine.patientMayRequestCancel(status: status), "\(status)")
        }
        XCTAssertFalse(BookingStateMachine.patientMayRequestCancel(status: .completed))
        XCTAssertFalse(BookingStateMachine.patientMayRequestCancel(status: .cancelled))
    }

    func testPatientTransitionsToCancelled() {
        let pairs: [(Booking.BookingStatus, Bool)] = [
            (.awaitingCaregiver, true),
            (.pending, true),
            (.confirmed, true),
            (.inProgress, true),
            (.completed, false),
            (.cancelled, false),
        ]
        for (from, ok) in pairs {
            XCTAssertEqual(
                BookingStateMachine.canTransition(from: from, to: .cancelled, actor: .patient),
                ok,
                "\(from.rawValue) -> cancelled"
            )
        }
    }

    func testCaregiverAcceptAndComplete() {
        XCTAssertTrue(BookingStateMachine.canTransition(from: .awaitingCaregiver, to: .confirmed, actor: .caregiver))
        XCTAssertTrue(BookingStateMachine.canTransition(from: .pending, to: .confirmed, actor: .caregiver))
        XCTAssertTrue(BookingStateMachine.canTransition(from: .confirmed, to: .inProgress, actor: .caregiver))
        XCTAssertTrue(BookingStateMachine.canTransition(from: .confirmed, to: .completed, actor: .caregiver))
        XCTAssertTrue(BookingStateMachine.canTransition(from: .inProgress, to: .completed, actor: .caregiver))
    }

    func testCaregiverDeclineOrCancel() {
        XCTAssertTrue(BookingStateMachine.canTransition(from: .awaitingCaregiver, to: .cancelled, actor: .caregiver))
        XCTAssertTrue(BookingStateMachine.canTransition(from: .pending, to: .cancelled, actor: .caregiver))
        XCTAssertTrue(BookingStateMachine.canTransition(from: .confirmed, to: .cancelled, actor: .caregiver))
        XCTAssertTrue(BookingStateMachine.canTransition(from: .inProgress, to: .cancelled, actor: .caregiver))
        XCTAssertFalse(BookingStateMachine.canTransition(from: .completed, to: .cancelled, actor: .caregiver))
    }

    func testNoOpTransitionRejected() {
        XCTAssertFalse(BookingStateMachine.canTransition(from: .confirmed, to: .confirmed, actor: .patient))
        XCTAssertFalse(BookingStateMachine.canTransition(from: .confirmed, to: .confirmed, actor: .caregiver))
    }

    func testConnectionSideEffects() {
        XCTAssertEqual(
            BookingStateMachine.connectionStatusAfterTransition(from: .awaitingCaregiver, to: .confirmed, actor: .caregiver),
            .approved
        )
        XCTAssertEqual(
            BookingStateMachine.connectionStatusAfterTransition(from: .pending, to: .confirmed, actor: .caregiver),
            .approved
        )
        XCTAssertEqual(
            BookingStateMachine.connectionStatusAfterTransition(from: .confirmed, to: .cancelled, actor: .caregiver),
            .rejected
        )
        XCTAssertNil(BookingStateMachine.connectionStatusAfterTransition(from: .confirmed, to: .confirmed, actor: .caregiver))
    }

    func testCallerMatches() {
        let b = Booking(
            id: "1",
            userId: "patientUid",
            patientName: "P",
            careRecipientId: nil,
            careRecipientRelation: nil,
            caregiverId: "cgUid",
            caregiverName: "C",
            caregiverSpecialty: "s",
            caregiverImageURL: "",
            caregiverRating: 5,
            date: Date(),
            startTime: Date(),
            endTime: Date(),
            duration: 1,
            totalCost: 0,
            status: .confirmed,
            location: "",
            address: "",
            paymentMethod: .cash,
            createdAt: Date(),
            cancellationRequestedByUid: nil,
            cancellationRequestedByRole: nil,
            cancellationRequestedAt: nil
        )
        XCTAssertTrue(BookingStateMachine.callerMatches(actor: .patient, booking: b, callerUid: "patientUid"))
        XCTAssertFalse(BookingStateMachine.callerMatches(actor: .patient, booking: b, callerUid: "cgUid"))
        XCTAssertTrue(BookingStateMachine.callerMatches(actor: .caregiver, booking: b, callerUid: "cgUid"))
        XCTAssertFalse(BookingStateMachine.callerMatches(actor: .caregiver, booking: b, callerUid: "patientUid"))
    }
}

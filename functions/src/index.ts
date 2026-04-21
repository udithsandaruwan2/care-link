import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";

admin.initializeApp();
const db = admin.firestore();

/** Matches `Booking.BookingStatus` raw values in the iOS client. */
const STATUS = {
  awaitingCaregiver: "Awaiting caregiver",
  pending: "Pending",
  confirmed: "Confirmed",
  inProgress: "In Progress",
  completed: "Completed",
  cancelled: "Cancelled",
} as const;

const BLOCKING_CREATE = new Set<string>([
  STATUS.awaitingCaregiver,
  STATUS.pending,
  STATUS.confirmed,
  STATUS.inProgress,
]);

function canTransition(
  role: "patient" | "caregiver",
  from: string,
  to: string
): boolean {
  if (from === to) return false;
  if (role === "patient") {
    const ok: [string, string][] = [
      [STATUS.awaitingCaregiver, STATUS.cancelled],
      [STATUS.pending, STATUS.cancelled],
      [STATUS.confirmed, STATUS.cancelled],
      [STATUS.inProgress, STATUS.cancelled],
    ];
    return ok.some(([a, b]) => a === from && b === to);
  }
  const ok: [string, string][] = [
    [STATUS.awaitingCaregiver, STATUS.confirmed],
    [STATUS.pending, STATUS.confirmed],
    [STATUS.awaitingCaregiver, STATUS.cancelled],
    [STATUS.pending, STATUS.cancelled],
    [STATUS.confirmed, STATUS.inProgress],
    [STATUS.confirmed, STATUS.completed],
    [STATUS.inProgress, STATUS.completed],
  ];
  return ok.some(([a, b]) => a === from && b === to);
}

function connectionStatusForTransition(
  role: "patient" | "caregiver",
  from: string,
  to: string
): "pending" | "approved" | "rejected" | null {
  if (to === STATUS.confirmed && role === "caregiver") {
    if (from === STATUS.awaitingCaregiver || from === STATUS.pending) return "approved";
  }
  if (to === STATUS.cancelled && from !== STATUS.completed) {
    return "rejected";
  }
  return null;
}

async function writeAudit(entry: Record<string, unknown>) {
  await db.collection("bookingAudits").add({
    ...entry,
    at: admin.firestore.FieldValue.serverTimestamp(),
  });
}

export const createBookingRequest = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const data = request.data as Record<string, unknown>;
  const booking = data.booking as Record<string, unknown> | undefined;
  if (!booking || typeof booking !== "object") {
    throw new HttpsError("invalid-argument", "Missing booking payload.");
  }
  const userId = booking.userId as string;
  const bookingId = booking.id as string;
  if (!userId || userId !== request.auth.uid) {
    throw new HttpsError("permission-denied", "Bookings must be created for the signed-in user.");
  }
  if (!bookingId) {
    throw new HttpsError("invalid-argument", "Booking id required.");
  }

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(
      db
        .collection("bookings")
        .where("userId", "==", userId)
        .where("status", "in", Array.from(BLOCKING_CREATE))
        .limit(5)
    );
    if (!snap.empty) {
      throw new HttpsError(
        "failed-precondition",
        "You already have an active booking request."
      );
    }
    tx.set(db.collection("bookings").doc(bookingId), booking);
  });

  await writeAudit({
    type: "createBookingRequest",
    bookingId,
    actorUid: request.auth.uid,
  });

  return { bookingId };
});

export const updateBookingStatus = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const bookingId = request.data.bookingId as string | undefined;
  const newStatus = request.data.newStatus as string | undefined;
  if (!bookingId || !newStatus) {
    throw new HttpsError("invalid-argument", "bookingId and newStatus are required.");
  }

  const ref = db.collection("bookings").doc(bookingId);
  const result = await db.runTransaction(async (tx) => {
    const doc = await tx.get(ref);
    if (!doc.exists) {
      throw new HttpsError("not-found", "Booking not found.");
    }
    const b = doc.data()!;
    const patientId = b.userId as string;
    const caregiverId = b.caregiverId as string;
    const fromStatus = b.status as string;

    const isPatient = request.auth!.uid === patientId;
    const isCaregiver = request.auth!.uid === caregiverId;
    if (!isPatient && !isCaregiver) {
      throw new HttpsError("permission-denied", "Not a participant on this booking.");
    }
    const role = isPatient ? "patient" : "caregiver";
    if (!canTransition(role, fromStatus, newStatus)) {
      throw new HttpsError("failed-precondition", "Invalid status transition.");
    }

    tx.update(ref, { status: newStatus });

    const connStatus = connectionStatusForTransition(role, fromStatus, newStatus);
    if (connStatus) {
      const cq = await tx.get(
        db
          .collection("connections")
          .where("userId", "==", patientId)
          .where("caregiverId", "==", caregiverId)
          .limit(1)
      );
      if (!cq.empty) {
        tx.update(cq.docs[0].ref, { status: connStatus });
      }
    }

    return { fromStatus, patientId, caregiverId, role };
  });

  await writeAudit({
    type: "updateBookingStatus",
    bookingId,
    fromStatus: result.fromStatus,
    toStatus: newStatus,
    actorUid: request.auth!.uid,
    role: result.role,
  });

  logger.info("Booking status updated", { bookingId, newStatus });
  return { ok: true };
});

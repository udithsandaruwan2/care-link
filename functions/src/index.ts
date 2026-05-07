import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import {
  BLOCKING_CREATE,
  STATUS,
  canTransition,
  connectionStatusForTransition,
} from "./bookingRules";

admin.initializeApp();
const db = admin.firestore();

function timestampFromUnknown(raw: unknown): admin.firestore.Timestamp | null {
  if (raw instanceof admin.firestore.Timestamp) return raw;
  if (raw instanceof Date) return admin.firestore.Timestamp.fromDate(raw);
  if (typeof raw === "number" && Number.isFinite(raw)) {
    return admin.firestore.Timestamp.fromMillis(raw);
  }
  if (typeof raw === "string") {
    const asNumber = Number(raw);
    if (Number.isFinite(asNumber)) {
      return admin.firestore.Timestamp.fromMillis(asNumber);
    }
    const parsed = Date.parse(raw);
    if (!Number.isNaN(parsed)) {
      return admin.firestore.Timestamp.fromMillis(parsed);
    }
  }
  return null;
}

function normalizeBookingPayloadForFirestore(
  booking: Record<string, unknown>
): Record<string, unknown> {
  const normalized: Record<string, unknown> = { ...booking };
  const dateKeys = ["date", "startTime", "endTime", "createdAt", "cancellationRequestedAt"];
  for (const key of dateKeys) {
    if (!(key in normalized)) continue;
    const ts = timestampFromUnknown(normalized[key]);
    if (ts) normalized[key] = ts;
    else delete normalized[key];
  }
  return normalized;
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
    const normalizedBooking = normalizeBookingPayloadForFirestore(booking);
    tx.set(db.collection("bookings").doc(bookingId), normalizedBooking);
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
    actorUid: request.auth.uid,
    role: result.role,
  });

  logger.info("Booking status updated", { bookingId, newStatus });
  return { ok: true };
});

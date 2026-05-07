import * as admin from "firebase-admin";

admin.initializeApp({ projectId: "care-plus-c135a" });
const db = admin.firestore();

type CaregiverDoc = {
  id: string;
  userId?: string;
  name?: string;
};

async function loadCaregiverMaps() {
  const caregiversSnap = await db.collection("caregivers").get();
  const byProfileIdToUserId = new Map<string, string>();
  const byNameToUserId = new Map<string, string>();
  const byUserIdToProfileId = new Map<string, string>();

  caregiversSnap.forEach((doc) => {
    const data = doc.data() as CaregiverDoc;
    const profileId = doc.id;
    const userId = data.userId ?? "";
    const name = (data.name ?? "").trim();
    if (!userId) return;
    byProfileIdToUserId.set(profileId, userId);
    byUserIdToProfileId.set(userId, profileId);
    if (name) byNameToUserId.set(name, userId);
  });

  return { byProfileIdToUserId, byNameToUserId, byUserIdToProfileId };
}

async function migrateBookings() {
  const { byProfileIdToUserId, byNameToUserId } = await loadCaregiverMaps();
  const snapshot = await db.collection("bookings").get();
  const batch = db.batch();
  let updates = 0;

  snapshot.forEach((doc) => {
    const data = doc.data() as Record<string, unknown>;
    const current = String(data.caregiverId ?? "");
    const caregiverName = String(data.caregiverName ?? "").trim();
    const fromProfile = byProfileIdToUserId.get(current);
    const fromName = caregiverName ? byNameToUserId.get(caregiverName) : undefined;
    const normalized = fromProfile ?? fromName ?? current;
    if (normalized && normalized !== current) {
      batch.update(doc.ref, { caregiverId: normalized });
      updates += 1;
    }
  });

  if (updates > 0) await batch.commit();
  return updates;
}

async function migrateConnections() {
  const { byProfileIdToUserId, byNameToUserId } = await loadCaregiverMaps();
  const snapshot = await db.collection("connections").get();
  const batch = db.batch();
  let updates = 0;

  snapshot.forEach((doc) => {
    const data = doc.data() as Record<string, unknown>;
    const current = String(data.caregiverId ?? "");
    const caregiverName = String(data.caregiverName ?? "").trim();
    const fromProfile = byProfileIdToUserId.get(current);
    const fromName = caregiverName ? byNameToUserId.get(caregiverName) : undefined;
    const normalized = fromProfile ?? fromName ?? current;
    if (normalized && normalized !== current) {
      batch.update(doc.ref, { caregiverId: normalized });
      updates += 1;
    }
  });

  if (updates > 0) await batch.commit();
  return updates;
}

async function mergeNotificationDocsForCaregivers() {
  const { byUserIdToProfileId } = await loadCaregiverMaps();
  let moved = 0;

  for (const [userId, profileId] of byUserIdToProfileId.entries()) {
    if (!profileId || profileId === userId) continue;

    const legacyRef = db.collection("users").doc(profileId).collection("notifications");
    const targetRef = db.collection("users").doc(userId).collection("notifications");
    const legacySnap = await legacyRef.get();
    if (legacySnap.empty) continue;

    const batch = db.batch();
    legacySnap.forEach((doc) => {
      batch.set(targetRef.doc(doc.id), doc.data(), { merge: true });
      batch.delete(doc.ref);
      moved += 1;
    });
    await batch.commit();
  }

  return moved;
}

async function main() {
  console.log("Starting caregiver data normalization...");
  const bookingUpdates = await migrateBookings();
  console.log(`Bookings normalized: ${bookingUpdates}`);
  const connectionUpdates = await migrateConnections();
  console.log(`Connections normalized: ${connectionUpdates}`);
  const movedNotifications = await mergeNotificationDocsForCaregivers();
  console.log(`Notifications moved to caregiver UID docs: ${movedNotifications}`);
  console.log("Done.");
}

main().catch((err) => {
  console.error("Normalization failed:", err);
  process.exit(1);
});


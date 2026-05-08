import * as admin from "firebase-admin";

admin.initializeApp({ projectId: "care-plus-c135a" });
const db = admin.firestore();

async function deleteCollection(collectionName: string): Promise<number> {
  const snapshot = await db.collection(collectionName).get();
  if (snapshot.empty) return 0;

  let deleted = 0;
  let batch = db.batch();
  let inBatch = 0;

  for (const doc of snapshot.docs) {
    batch.delete(doc.ref);
    inBatch += 1;
    deleted += 1;

    // Firestore batch write max is 500.
    if (inBatch === 450) {
      await batch.commit();
      batch = db.batch();
      inBatch = 0;
    }
  }

  if (inBatch > 0) {
    await batch.commit();
  }

  return deleted;
}

async function main() {
  console.log("Starting cleanup for bookings and connections...");
  const deletedBookings = await deleteCollection("bookings");
  console.log(`Deleted bookings: ${deletedBookings}`);
  const deletedConnections = await deleteCollection("connections");
  console.log(`Deleted connections: ${deletedConnections}`);
  console.log("Cleanup completed.");
}

main().catch((err) => {
  console.error("Cleanup failed:", err);
  process.exit(1);
});

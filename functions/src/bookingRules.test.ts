import assert from "node:assert/strict";
import { BLOCKING_CREATE, canTransition, connectionStatusForTransition, STATUS } from "./bookingRules";

// Patient may only cancel into terminal cancelled from open states
assert.equal(canTransition("patient", STATUS.awaitingCaregiver, STATUS.cancelled), true);
assert.equal(canTransition("patient", STATUS.confirmed, STATUS.cancelled), true);
assert.equal(canTransition("patient", STATUS.confirmed, STATUS.confirmed), false);

// Caregiver accept / decline / visit lifecycle
assert.equal(canTransition("caregiver", STATUS.awaitingCaregiver, STATUS.confirmed), true);
assert.equal(canTransition("caregiver", STATUS.pending, STATUS.cancelled), true);
assert.equal(canTransition("caregiver", STATUS.confirmed, STATUS.inProgress), true);
assert.equal(canTransition("caregiver", STATUS.inProgress, STATUS.completed), true);

// Caregiver-initiated cancel from live states (aligned with iOS BookingStateMachine)
assert.equal(canTransition("caregiver", STATUS.confirmed, STATUS.cancelled), true);
assert.equal(canTransition("caregiver", STATUS.inProgress, STATUS.cancelled), true);

// Invalid jumps
assert.equal(canTransition("caregiver", STATUS.completed, STATUS.cancelled), false);
assert.equal(canTransition("patient", STATUS.completed, STATUS.cancelled), false);

// Patient cannot move workflow forward
assert.equal(canTransition("patient", STATUS.awaitingCaregiver, STATUS.confirmed), false);
assert.equal(canTransition("patient", STATUS.confirmed, STATUS.inProgress), false);
assert.equal(canTransition("patient", STATUS.inProgress, STATUS.completed), false);

// Connection side-effect expectations
assert.equal(connectionStatusForTransition("caregiver", STATUS.awaitingCaregiver, STATUS.confirmed), "approved");
assert.equal(connectionStatusForTransition("caregiver", STATUS.pending, STATUS.confirmed), "approved");
assert.equal(connectionStatusForTransition("caregiver", STATUS.confirmed, STATUS.cancelled), "rejected");
assert.equal(connectionStatusForTransition("patient", STATUS.confirmed, STATUS.cancelled), "rejected");
assert.equal(connectionStatusForTransition("caregiver", STATUS.inProgress, STATUS.completed), null);

// Active bookings should block new create requests
assert.equal(BLOCKING_CREATE.has(STATUS.confirmed), true);
assert.equal(BLOCKING_CREATE.has(STATUS.inProgress), true);
assert.equal(BLOCKING_CREATE.has(STATUS.completed), false);

console.log("bookingRules.test.ts: all assertions passed");

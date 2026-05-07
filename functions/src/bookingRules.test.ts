import assert from "node:assert/strict";
import { canTransition, STATUS } from "./bookingRules";

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

console.log("bookingRules.test.ts: all assertions passed");

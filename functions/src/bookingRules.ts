// File responsibility: Defines booking rules logic for cloud functions.

/**
 * Booking transition matrix shared with iOS `BookingStateMachine` in
 * `care link/care link/Models/BookingStateMachine.swift`. Update both when rules change.
 */
/** Matches `Booking.BookingStatus` raw values in the iOS client. */
export const STATUS = {
  awaitingCaregiver: "Awaiting caregiver",
  pending: "Pending",
  confirmed: "Confirmed",
  inProgress: "In Progress",
  completed: "Completed",
  cancelled: "Cancelled",
} as const;

export const BLOCKING_CREATE = new Set<string>([
  STATUS.confirmed,
  STATUS.inProgress,
]);

export function canTransition(
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
    [STATUS.confirmed, STATUS.cancelled],
    [STATUS.inProgress, STATUS.completed],
    [STATUS.inProgress, STATUS.cancelled],
  ];
  return ok.some(([a, b]) => a === from && b === to);
}

export function connectionStatusForTransition(
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

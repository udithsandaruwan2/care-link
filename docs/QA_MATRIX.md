# CareLink QA matrix (two roles)

Run these flows on two simulators or devices signed in as **patient** and **caregiver** with distinct Firebase accounts. Record pass/fail and any Firestore console errors (especially composite index prompts).

## Booking

| # | Scenario | Patient | Caregiver | Pass |
|---|----------|---------|-----------|------|
| 1 | Patient books caregiver from Home → profile → confirm | Creates booking `Awaiting caregiver`, chat booking bubble | Sees request in Dashboard **Pending** and in chat |  |
| 2 | Caregiver accepts from dashboard | Status → **Confirmed**, connection approved | Pending queue decreases |  |
| 3 | Caregiver accepts from chat booking card | Same as (2) | Accept from `ChatDetailView` |  |
| 4 | Caregiver declines from dashboard or chat | Status **Cancelled**, connection rejected | — |  |
| 5 | Patient cancels from Home sticky card / My care hub | **Cancelled**, connection rejected if applicable | Request clears |  |
| 6 | Global lock: with active pipeline, patient cannot book another caregiver from profile/details | Error or disabled UI | — |  |
| 7 | Map tab with active request | Blocking overlay → **My care hub** | — |  |
| 8 | Caregiver **Start visit** then **Mark complete** | Patient sees terminal **Completed** in hub | Earnings card reflects completed booking total |  |

## Chat

| # | Scenario | Expected | Pass |
|---|----------|----------|------|
| 9 | Send text after booking | `lastMessage`, `lastMessageAt`, unread counter on recipient update in one logical send |  |
| 10 | Open thread as recipient | Unread resets via batched read + conversation update |  |
| 11 | Malformed legacy message doc in thread | App keeps showing valid messages; bad doc logged, not fatal |  |

## Map

| # | Scenario | Expected | Pass |
|---|----------|----------|------|
| 12 | Patient map without active booking | Pins selectable, profile navigation works |  |
| 13 | Patient map with active booking | Overlay blocks browsing; hub link works |  |

## Biometrics & settings

| # | Scenario | Expected | Pass |
|---|----------|----------|------|
| 14 | Toggle Dark Mode | App-wide appearance toggles; survives relaunch |  |
| 15 | Toggle Push Notifications on | System permission dialog; toggle off if denied |  |
| 16 | Biometric login (if enabled) | Cold start lock when configured |  |

## Backend (staging)

| # | Scenario | Expected | Pass |
|---|----------|----------|------|
| 17 | Deploy `firestore.rules` + `firestore.indexes.json` | No permission-denied for normal flows; indexes build |  |
| 18 | Deploy Functions `createBookingRequest` / `updateBookingStatus` (optional client wiring) | Duplicate create rejected; invalid transition rejected; `bookingAudits` rows appear |  |

## Sign-off

Tester: ______________  Date: ______________  Build / commit: ______________

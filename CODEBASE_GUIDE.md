# CareLink Codebase Guide

This document explains the CareLink iOS app architecture, feature modules, and the core concepts behind the code.

## 1) High-level architecture

CareLink is a SwiftUI app with a lightweight service + view model architecture:

- **Views** render UI and user interactions.
- **ViewModels** hold screen state and orchestration logic.
- **Services** handle integrations (Firebase, biometrics, EventKit, location, Core ML wrappers).
- **Models** define app domain entities (`CLUser`, `Caregiver`, `Booking`, etc).
- **AppState** is the global shared state container injected into the SwiftUI environment.

The app is designed so most business logic is outside view files, and views remain mostly declarative.

## 2) Project layout

Main app code is under:

- `care link/care link/`

Important folders:

- `Views/` - all SwiftUI screens, grouped by feature.
- `ViewModels/` - screen state and logic.
- `Services/` - external API and platform integrations.
- `Models/` - domain data structures.
- `Core/` - reusable design system components and theming.

## 3) Design system and UI conventions

The app uses a custom design system to keep visual consistency:

- `Core/Theme.swift` (`CLTheme`)
  - colors, typography, spacing, corner radius, shadows.
- `Core/Components/CLButton.swift`
  - primary/secondary/outline/text styles.
- `Core/Components/CLCard.swift`
  - card container with consistent rounding and elevation.
- `Core/Components/CLNavigationBar.swift`
  - top bar with logo/back/filter controls.
- `Core/Components/CLChip.swift`, `CLTabBar.swift`, `CLTextField.swift`
  - reusable controls.

Concept: UI files should use these components instead of re-creating style rules in each screen.

## 4) Global state and app lifecycle

`ViewModels/AppState.swift` is the app-wide state hub.

Key responsibilities:

- authentication state (`isAuthenticated`, role, setup flags),
- app navigation reset token,
- biometric lock state (`isBiometricAppLocked`),
- service instances (`authService`, `firestoreService`, `chatService`, etc).

Lifecycle handling:

- `ContentView.swift` listens to `scenePhase`.
- On `.inactive` / `.background`, app may lock via biometrics.
- On foreground, biometric lock overlay (`BiometricLockScreenView`) can gate content.

Concept: app-level concerns are centralized in `AppState` so feature screens stay focused.

## 5) Authentication and profile bootstrap

Auth entry:

- `Views/Auth/LoginView.swift`
- `ViewModels/AuthViewModel.swift`
- `Services/AuthService.swift`

Supported sign-in:

- email/password,
- Google Sign-In.

First-time profile setup:

- `Views/Auth/NewUserSetupView.swift`
  - collects profile basics + role.
- creates `CLUser` in Firestore.

Concept: Firebase Auth manages identity, Firestore user profile stores role and app-specific metadata.

## 6) Biometric security model

Core files:

- `Services/BiometricService.swift`
  - uses `LocalAuthentication` with `.deviceOwnerAuthentication` (Face ID / Touch ID / passcode).
- `Services/BiometricCredentialStore.swift`
  - stores email/password in Keychain for quick sign-in,
  - stores non-secret display email in `UserDefaults`.
- `Views/Auth/BiometricLockScreenView.swift`
  - full-screen lock overlay with auto auth attempt.
- `Views/Settings/SettingsView.swift`
  - user-controlled biometric enable/disable.

Enablement model:

- App lock is active only when both are true:
  - local preference key (`carelink.biometricAppUnlockEnabled`),
  - profile flag (`CLUser.isBiometricEnabled`).

Important behavior:

- Opening Settings no longer auto-triggers biometric prompt (guarded initialization logic).
- Toggle changes require explicit user action.

## 7) Data layer (Firestore)

`Services/FirestoreService.swift` wraps Firestore access for:

- caregivers,
- bookings,
- reviews,
- connections,
- medical records,
- users,
- family members.

Pattern:

- strongly-typed decode with `doc.data(as:)`,
- collection-specific fetch/update methods,
- async/await usage throughout.

Concept: this keeps Firestore query details out of view/view-model code.

## 8) Map and location module

Core files:

- `Views/Map/CaregiverMapView.swift`
- `ViewModels/MapViewModel.swift`
- `Services/LocationService.swift`

Capabilities:

- MapKit map with caregiver annotations + user annotation.
- live search filter (name/specialty),
- debounced search,
- specialty chips,
- no-match state and reset.

Permissions:

- `Info.plist` includes `NSLocationWhenInUseUsageDescription`.
- `LocationService` requests `whenInUse` authorization and updates coordinate.

Concept: map screen uses `MapViewModel.filteredCaregivers` as the single source for what pins are visible.

## 9) Booking module

Core files:

- `Views/Booking/BookingDetailsView.swift`
- `Views/Booking/BookingConfirmationView.swift`
- `ViewModels/BookingViewModel.swift`

Flow:

1. User selects date/time/duration/payment.
2. `BookingViewModel` creates a booking payload.
3. Booking is written to Firestore.
4. Related chat request message is sent.
5. Confirmation screen can add to calendar.

Booking status model:

- `awaitingCaregiver`, `pending`, `confirmed`, `inProgress`, `completed`, `cancelled`.

## 10) EventKit integration

`Services/EventKitService.swift`:

- requests calendar access (`requestFullAccessToEvents`),
- creates `EKEvent` from booking details,
- sets reminder alarm.

Used by:

- `Views/Booking/BookingConfirmationView.swift` via "Add to Calendar".

`Info.plist` includes:

- `NSCalendarsFullAccessUsageDescription`.

## 11) Core ML integration strategy

The app uses a safe model-wrapper pattern with fallback:

- `Services/CoreMLModelProvider.swift`
  - generic model loading and inference from `.mlmodelc`.
- `Services/CoreMLRecommendationService.swift`
  - ranks caregivers using model features if model exists,
  - falls back to deterministic `RecommendationService`.
- `Services/CoreMLBookingRiskService.swift`
  - predicts cancellation/no-show risk score,
  - returns `BookingRiskAssessment` (`low`/`medium`/`high`),
  - deterministic fallback if model missing.

Current model names expected in bundle:

- `CaregiverRecommender.mlmodelc`
- `BookingRiskClassifier.mlmodelc`

Concept: app behavior remains stable even without shipped ML assets.

## 12) Home recommendations

Core files:

- `Views/Home/HomeView.swift`
- `ViewModels/HomeViewModel.swift`

Behavior:

- caregivers load from Firestore,
- booking history loads for personalization context,
- recommendations are produced via `CoreMLRecommendationService`,
- final visible list still respects search/category/filter settings.

Additional home feature:

- top-right filter button opens a filter sheet:
  - sort options,
  - budget filter slider.

## 13) Caregiver portal

Core files:

- `Views/CaregiverPortal/CaregiverDashboardView.swift`
- `ViewModels/CaregiverPortalViewModel.swift`

Responsibilities:

- pending/upcoming/completed appointment segmentation,
- accept/reject/complete booking actions,
- connected patient views,
- risk chip display for pending requests via booking risk service.

Concept: caregiver dashboard acts as a work queue for operational decisions.

## 14) Profile, settings, family, and payments

Profile hub:

- `Views/Profile/ProfileView.swift`
  - account sections, support links, sign out, navigation to sub-features.

Edit profile:

- `Views/Profile/EditProfileView.swift`

Family management:

- `Models/FamilyMember.swift`
- `Views/Profile/FamilyMembersView.swift`
- `Views/Profile/AddFamilyMemberView.swift`
- Firestore CRUD methods in `FirestoreService`.

Payment UI/local wallet:

- `Models/PaymentCard.swift`
- `Services/PaymentCardStore.swift` (UserDefaults-backed local card store)
- `Views/Profile/PaymentMethodsView.swift`
- `Views/Profile/AddNewCardView.swift`

Concept: family data is cloud-backed; payment card mock wallet is local for now.

## 15) Key domain models

Important models and what they represent:

- `CLUser` - app user profile + role + biometric flag.
- `Caregiver` - caregiver listing profile + pricing/location/skills.
- `Booking` - care session request and lifecycle status.
- `Connection` - relationship approval between user and caregiver.
- `ChatMessage` / `ChatConversation` - messaging entities.
- `MedicalRecord` - patient health records.
- `FamilyMember` - family profile under a user account.
- `PaymentCard` - local wallet card representation.

## 16) Security and privacy concepts

- Sensitive credentials for quick login are stored in **Keychain**.
- Non-secret UI display hints (email, preferences) use `UserDefaults`.
- Biometric lock uses platform authentication policy with passcode fallback.
- Family and medical records are designed around authenticated user ownership.

## 17) How to extend safely

When adding new features:

1. Add/extend model in `Models/`.
2. Add service API in `Services/`.
3. Add/update view model orchestration.
4. Keep views declarative and style with `CLTheme` + core components.
5. Add fallbacks when depending on optional platform/model capabilities.

## 18) Known implementation notes

- Core ML wrappers currently support missing models by design (fallback path).
- Payment methods currently use local storage (`PaymentCardStore`) and not remote tokenized payment APIs.
- Some support/about rows are UI placeholders pending backend destinations.

---

If you want, the next step can be a second document focused on **data flow diagrams** (Auth, Booking, Chat, Map, and Biometric lifecycle) for onboarding new developers quickly.

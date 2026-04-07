# CareLink

**Your Digital Health Sanctuary** — An iOS application connecting users with trusted caregivers for elderly care, childcare, and home assistance.

## Architecture

- **Pattern**: MVVM + Repository
- **UI**: SwiftUI with glass/minimal design
- **Backend**: Firebase (Auth, Firestore, Cloud Messaging, Storage)
- **Local Storage**: Core Data
- **Minimum Target**: iOS 26.2

## Project Structure

```
care link/care link/
├── App/                    # AppDelegate, Firebase setup
├── Core/
│   ├── Components/         # CLButton, CLTextField, CLCard, CLTabBar, etc.
│   ├── Extensions/         # Color+Extensions, View+Extensions
│   └── Theme.swift         # Design system (colors, fonts, spacing)
├── Models/                 # User, Caregiver, Booking, Review, Notification
├── ViewModels/             # AppState, AuthVM, HomeVM, BookingVM, MapVM, PortalVM
├── Views/
│   ├── Welcome/            # Landing screen
│   ├── Onboarding/         # 3-page onboarding flow
│   ├── Auth/               # Login, SignUp, FaceID
│   ├── Home/               # Find Care dashboard, caregiver cards
│   ├── Booking/            # Caregiver profile, booking details, confirmation
│   ├── Map/                # MapKit-based caregiver discovery
│   ├── CaregiverPortal/    # Caregiver dashboard & profile editing
│   ├── Profile/            # User profile & booking history
│   ├── Settings/           # Preferences, privacy, accessibility
│   ├── Alerts/             # Notification center
│   └── MainTab/            # Tab bar controller
├── Services/               # Auth, Firestore, Biometric, Notification, Location, EventKit, ML
├── Repositories/           # Core Data persistence
└── Resources/              # GoogleService-Info.plist
```

## Features

### Core
- Email/password authentication via Firebase Auth
- Face ID / Touch ID biometric login
- Caregiver search with category filters (Elderly, Child, Home Assistance)
- Detailed caregiver profiles with reviews
- Booking flow with calendar and time picker
- Push notifications (Firebase Cloud Messaging)
- Core Data offline caching

### Advanced
- Core ML-based caregiver recommendations
- MapKit integration with caregiver pins
- EventKit calendar integration for booking reminders

### Two-Sided Platform
- **User Portal**: Find, evaluate, and book caregivers
- **Caregiver Portal**: Manage appointments, accept/reject bookings, edit profile

## Setup

1. Open `care link.xcodeproj` in Xcode
2. Wait for Swift Package Manager to resolve Firebase dependencies
3. Ensure `GoogleService-Info.plist` is in `Resources/`
4. Select a development team under Signing & Capabilities
5. Build and run on simulator or device

## Frameworks Used

| Framework | Purpose |
|-----------|---------|
| SwiftUI | User interface |
| Firebase Auth | Authentication |
| Firebase Firestore | Cloud database |
| Firebase Messaging | Push notifications |
| Firebase Storage | File storage |
| Core Data | Local persistence |
| LocalAuthentication | Face ID / Touch ID |
| MapKit | Map-based discovery |
| EventKit | Calendar integration |
| Core ML | Recommendation engine |
| UserNotifications | Local notifications |

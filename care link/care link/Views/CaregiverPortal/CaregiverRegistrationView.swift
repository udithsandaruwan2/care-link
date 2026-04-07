import SwiftUI
import MapKit
import FirebaseAuth

struct CaregiverRegistrationView: View {
    @Environment(AppState.self) private var appState
    @State private var currentStep = 0
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    // Step 1: Personal Info
    @State private var fullName = ""
    @State private var specialty = ""
    @State private var title = ""
    @State private var bio = ""
    @State private var phoneNumber = ""

    // Step 2: Rates & Availability
    @State private var hourlyRate = ""
    @State private var experienceYears = ""
    @State private var selectedCategory: Caregiver.CareCategory = .elderly
    @State private var selectedAvailability: Set<String> = []

    // Step 3: Skills & Certifications
    @State private var skills = ""
    @State private var certifications = ""

    // Step 4: Location
    @State private var useCurrentLocation = true
    @State private var mapPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 6.9271, longitude: 79.8612),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    )
    @State private var selectedCoordinate = CLLocationCoordinate2D(latitude: 6.9271, longitude: 79.8612)

    private let steps = ["Personal Info", "Rates", "Skills", "Location"]
    private let availabilityOptions = ["Morning", "Afternoon", "Evening", "Night", "Full Day", "Weekends"]

    var body: some View {
        VStack(spacing: 0) {
            header
            progressIndicator

            TabView(selection: $currentStep) {
                personalInfoStep.tag(0)
                ratesStep.tag(1)
                skillsStep.tag(2)
                locationStep.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentStep)

            bottomBar
        }
        .background(CLTheme.backgroundPrimary)
        .alert("Save Failed", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            if let profile = appState.authService.userProfile {
                fullName = profile.fullName
                phoneNumber = profile.phoneNumber
            }
            if let coordinate = appState.locationService.userLocation {
                selectedCoordinate = coordinate
                mapPosition = .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                ))
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: CLTheme.spacingSM) {
            HStack {
                Image(systemName: "cross.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(CLTheme.primaryNavy)
                Text("CareLink")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(CLTheme.primaryNavy)
            }
            .padding(.top, CLTheme.spacingLG)

            Text("Complete Your Profile")
                .font(CLTheme.titleFont)
                .foregroundStyle(CLTheme.textPrimary)

            Text("Set up your caregiver profile to start receiving clients")
                .font(CLTheme.captionFont)
                .foregroundStyle(CLTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, CLTheme.spacingLG)
    }

    // MARK: - Progress

    private var progressIndicator: some View {
        HStack(spacing: CLTheme.spacingSM) {
            ForEach(0..<steps.count, id: \.self) { index in
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(index <= currentStep ? CLTheme.primaryNavy : CLTheme.backgroundSecondary)
                            .frame(width: 32, height: 32)
                        if index < currentStep {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(index == currentStep ? .white : CLTheme.textTertiary)
                        }
                    }
                    Text(steps[index])
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(index <= currentStep ? CLTheme.primaryNavy : CLTheme.textTertiary)
                }
                if index < steps.count - 1 {
                    Rectangle()
                        .fill(index < currentStep ? CLTheme.primaryNavy : CLTheme.backgroundSecondary)
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 16)
                }
            }
        }
        .padding(.horizontal, CLTheme.spacingLG)
        .padding(.vertical, CLTheme.spacingMD)
    }

    // MARK: - Step 1: Personal Info

    private var personalInfoStep: some View {
        ScrollView {
            VStack(spacing: CLTheme.spacingLG) {
                sectionCard("About You") {
                    formField("Full Name", text: $fullName, icon: "person.fill")
                    formField("Phone Number", text: $phoneNumber, icon: "phone.fill", keyboard: .phonePad)
                    formField("Professional Title (e.g. RN, PTA)", text: $title, icon: "briefcase.fill")
                    formField("Specialty", text: $specialty, icon: "stethoscope")

                    VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                        Text("BIO")
                            .font(CLTheme.smallFont)
                            .foregroundStyle(CLTheme.textTertiary)
                            .tracking(1)
                        TextEditor(text: $bio)
                            .font(CLTheme.bodyFont)
                            .frame(minHeight: 100)
                            .padding(CLTheme.spacingSM)
                            .background(CLTheme.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD))
                    }
                }
            }
            .padding(.bottom, 100)
        }
    }

    // MARK: - Step 2: Rates & Availability

    private var ratesStep: some View {
        ScrollView {
            VStack(spacing: CLTheme.spacingLG) {
                sectionCard("Rates & Experience") {
                    formField("Hourly Rate ($)", text: $hourlyRate, icon: "dollarsign.circle.fill", keyboard: .decimalPad)
                    formField("Years of Experience", text: $experienceYears, icon: "clock.fill", keyboard: .numberPad)

                    VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                        Text("CARE CATEGORY")
                            .font(CLTheme.smallFont)
                            .foregroundStyle(CLTheme.textTertiary)
                            .tracking(1)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: CLTheme.spacingSM) {
                            ForEach(Caregiver.CareCategory.allCases.filter { $0 != .all }, id: \.self) { cat in
                                Button {
                                    selectedCategory = cat
                                } label: {
                                    Text(cat.rawValue)
                                        .font(CLTheme.calloutFont)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .foregroundStyle(selectedCategory == cat ? .white : CLTheme.textPrimary)
                                        .background(selectedCategory == cat ? CLTheme.primaryNavy : CLTheme.backgroundSecondary)
                                        .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD))
                                }
                            }
                        }
                    }
                }

                sectionCard("Availability") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: CLTheme.spacingSM) {
                        ForEach(availabilityOptions, id: \.self) { slot in
                            Button {
                                if selectedAvailability.contains(slot) {
                                    selectedAvailability.remove(slot)
                                } else {
                                    selectedAvailability.insert(slot)
                                }
                            } label: {
                                Text(slot)
                                    .font(CLTheme.captionFont)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(selectedAvailability.contains(slot) ? .white : CLTheme.textPrimary)
                                    .background(selectedAvailability.contains(slot) ? CLTheme.tealAccent : CLTheme.backgroundSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusSM))
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 100)
        }
    }

    // MARK: - Step 3: Skills

    private var skillsStep: some View {
        ScrollView {
            VStack(spacing: CLTheme.spacingLG) {
                sectionCard("Skills") {
                    VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                        Text("SKILLS (comma separated)")
                            .font(CLTheme.smallFont)
                            .foregroundStyle(CLTheme.textTertiary)
                            .tracking(1)
                        TextEditor(text: $skills)
                            .font(CLTheme.bodyFont)
                            .frame(minHeight: 80)
                            .padding(CLTheme.spacingSM)
                            .background(CLTheme.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD))
                        Text("e.g. Wound Care, Vital Monitoring, Meal Preparation")
                            .font(CLTheme.captionFont)
                            .foregroundStyle(CLTheme.textTertiary)
                    }
                }

                sectionCard("Certifications") {
                    VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                        Text("CERTIFICATIONS (comma separated)")
                            .font(CLTheme.smallFont)
                            .foregroundStyle(CLTheme.textTertiary)
                            .tracking(1)
                        TextEditor(text: $certifications)
                            .font(CLTheme.bodyFont)
                            .frame(minHeight: 80)
                            .padding(CLTheme.spacingSM)
                            .background(CLTheme.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD))
                        Text("e.g. BLS Certified, Nursing License, CPR Certified")
                            .font(CLTheme.captionFont)
                            .foregroundStyle(CLTheme.textTertiary)
                    }
                }
            }
            .padding(.bottom, 100)
        }
    }

    // MARK: - Step 4: Location

    private var locationStep: some View {
        ScrollView {
            VStack(spacing: CLTheme.spacingLG) {
                sectionCard("Your Service Location") {
                    VStack(spacing: CLTheme.spacingMD) {
                        Text("Drop a pin on your service area so patients can find you nearby.")
                            .font(CLTheme.bodyFont)
                            .foregroundStyle(CLTheme.textSecondary)

                        Map(position: $mapPosition, interactionModes: .all) {
                            Annotation("You", coordinate: selectedCoordinate) {
                                ZStack {
                                    Circle()
                                        .fill(CLTheme.primaryNavy)
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusLG))
                        .onMapCameraChange(frequency: .onEnd) { context in
                            selectedCoordinate = context.camera.centerCoordinate
                        }

                        Button {
                            if let coordinate = appState.locationService.userLocation {
                                selectedCoordinate = coordinate
                                mapPosition = .region(MKCoordinateRegion(
                                    center: coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                                ))
                            }
                        } label: {
                            HStack {
                                Image(systemName: "location.fill")
                                Text("Use My Current Location")
                                    .font(CLTheme.calloutFont)
                            }
                            .foregroundStyle(CLTheme.accentBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(CLTheme.lightBlue)
                            .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD))
                        }
                    }
                }
            }
            .padding(.bottom, 100)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: CLTheme.spacingMD) {
            if currentStep > 0 {
                Button {
                    withAnimation { currentStep -= 1 }
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(CLTheme.calloutFont)
                    .foregroundStyle(CLTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(CLTheme.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD))
                }
            }

            Button {
                if currentStep < steps.count - 1 {
                    withAnimation { currentStep += 1 }
                } else {
                    saveProfile()
                }
            } label: {
                HStack {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(currentStep < steps.count - 1 ? "Continue" : "Complete Setup")
                            .font(CLTheme.headlineFont)
                        Image(systemName: currentStep < steps.count - 1 ? "arrow.right" : "checkmark")
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(CLTheme.gradientBlue)
                .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD))
            }
            .disabled(isSaving)
        }
        .padding(.horizontal, CLTheme.spacingLG)
        .padding(.vertical, CLTheme.spacingMD)
        .background(CLTheme.cardBackground.shadow(color: CLTheme.shadowMedium, radius: 8, y: -2))
    }

    // MARK: - Helpers

    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            Text(title)
                .font(CLTheme.title2Font)
                .foregroundStyle(CLTheme.textPrimary)

            VStack(spacing: CLTheme.spacingMD) {
                content()
            }
            .padding(CLTheme.spacingMD)
            .background(CLTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusLG))
            .shadow(color: CLTheme.shadowLight, radius: 4)
        }
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private func formField(_ placeholder: String, text: Binding<String>, icon: String, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
            Text(placeholder.uppercased())
                .font(CLTheme.smallFont)
                .foregroundStyle(CLTheme.textTertiary)
                .tracking(1)
            CLTextField(placeholder: placeholder, text: text, icon: icon, keyboardType: keyboard)
        }
    }

    private func saveProfile() {
        isSaving = true
        Task {
            let uid = appState.authService.currentUser?.uid ?? UUID().uuidString
            let caregiver = Caregiver(
                id: uid,
                userId: uid,
                name: fullName,
                specialty: specialty,
                title: title,
                hourlyRate: Double(hourlyRate) ?? 0,
                rating: 0,
                reviewCount: 0,
                experienceYears: Int(experienceYears) ?? 0,
                distance: 0,
                bio: bio,
                skills: skills.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
                certifications: certifications.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
                availability: Array(selectedAvailability),
                imageURL: "",
                latitude: selectedCoordinate.latitude,
                longitude: selectedCoordinate.longitude,
                isVerified: false,
                category: selectedCategory,
                phoneNumber: phoneNumber,
                email: appState.authService.userProfile?.email ?? ""
            )

            do {
                try await appState.firestoreService.createCaregiverProfile(caregiver)
                await MainActor.run {
                    appState.completeCaregiverRegistration()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            await MainActor.run { isSaving = false }
        }
    }
}

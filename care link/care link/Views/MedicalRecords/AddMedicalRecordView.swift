import SwiftUI
import FirebaseAuth

struct AddMedicalRecordView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let patientId: String
    let patientName: String
    var onSave: () -> Void

    @State private var title = ""
    @State private var recordDescription = ""
    @State private var notes = ""
    @State private var selectedType: MedicalRecord.RecordType = .note
    @State private var date = Date()
    @State private var isSaving = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CLTheme.spacingLG) {
                    patientHeader

                    sectionCard("Record Type") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: CLTheme.spacingSM) {
                            ForEach(MedicalRecord.RecordType.allCases, id: \.self) { type in
                                Button {
                                    selectedType = type
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: type.iconName)
                                            .font(.system(size: 20))
                                        Text(type.rawValue)
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .foregroundStyle(selectedType == type ? .white : Color(hex: type.colorHex))
                                    .background(selectedType == type ? Color(hex: type.colorHex) : Color(hex: type.colorHex).opacity(0.1))
                                    .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusMD))
                                }
                            }
                        }
                    }

                    sectionCard("Details") {
                        VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                            Text("TITLE")
                                .font(CLTheme.smallFont)
                                .foregroundStyle(CLTheme.textTertiary)
                                .tracking(1)
                            CLTextField(placeholder: "e.g. Blood Pressure Check", text: $title, icon: "doc.text")
                        }

                        VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                            Text("DESCRIPTION")
                                .font(CLTheme.smallFont)
                                .foregroundStyle(CLTheme.textTertiary)
                                .tracking(1)
                            TextEditor(text: $recordDescription)
                                .font(CLTheme.bodyFont)
                                .frame(minHeight: 100)
                                .padding(CLTheme.spacingSM)
                                .background(CLTheme.backgroundSecondary)
                                .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusMD))
                        }

                        VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                            Text("NOTES (optional)")
                                .font(CLTheme.smallFont)
                                .foregroundStyle(CLTheme.textTertiary)
                                .tracking(1)
                            CLTextField(placeholder: "Additional notes", text: $notes, icon: "note.text")
                        }

                        VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                            Text("DATE")
                                .font(CLTheme.smallFont)
                                .foregroundStyle(CLTheme.textTertiary)
                                .tracking(1)
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .labelsHidden()
                                .tint(CLTheme.primaryNavy)
                        }
                    }

                    CLButton(title: "Save Record", icon: "checkmark.circle", isLoading: isSaving) {
                        saveRecord()
                    }
                    .padding(.horizontal, CLTheme.spacingMD)
                    .disabled(title.isEmpty || recordDescription.isEmpty)
                }
                .padding(.bottom, CLTheme.spacingXL)
            }
            .background(CLTheme.backgroundPrimary)
            .navigationTitle("Add Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(CLTheme.textSecondary)
                }
            }
            .alert("Could not save record", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage)
            }
        }
    }

    private var patientHeader: some View {
        HStack(spacing: CLTheme.spacingMD) {
            Circle()
                .fill(CLTheme.primaryNavy.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(String(patientName.prefix(2)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(CLTheme.primaryNavy)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text("Patient")
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.textSecondary)
                Text(patientName)
                    .font(CLTheme.headlineFont)
                    .foregroundStyle(CLTheme.textPrimary)
            }
            Spacer()
        }
        .padding(CLTheme.spacingMD)
        .background(CLTheme.lightBlue)
        .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusMD))
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private func sectionCard<Content: View>(_ sectionTitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            Text(sectionTitle)
                .font(CLTheme.title2Font)
                .foregroundStyle(CLTheme.textPrimary)
                .padding(.horizontal, CLTheme.spacingMD)

            VStack(spacing: CLTheme.spacingMD) {
                content()
            }
            .padding(CLTheme.spacingMD)
            .background(CLTheme.cardBackground)
            .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusLG))
            .shadow(color: CLTheme.shadowLight, radius: 6, y: 2)
            .padding(.horizontal, CLTheme.spacingMD)
        }
    }

    private func saveRecord() {
        isSaving = true
        Task {
            let caregiverId = appState.authService.currentUser?.uid ?? ""
            guard !caregiverId.isEmpty else {
                await MainActor.run {
                    isSaving = false
                    saveErrorMessage = "You must be logged in as a caregiver to add records."
                    showSaveError = true
                }
                return
            }
            let caregiverName = appState.authService.userProfile?.fullName ?? "Caregiver"

            let record = MedicalRecord(
                id: UUID().uuidString,
                patientId: patientId,
                patientName: patientName,
                caregiverId: caregiverId,
                caregiverName: caregiverName,
                title: title,
                recordDescription: recordDescription,
                recordType: selectedType,
                date: date,
                notes: notes,
                createdAt: Date()
            )

            do {
                try await appState.firestoreService.addMedicalRecord(record)
                try? await appState.firestoreService.createNotification(
                    CLNotification(
                        id: UUID().uuidString,
                        userId: patientId,
                        senderUserId: caregiverId,
                        title: "New medical record",
                        message: "\(caregiverName) added \"\(title)\" to your records.",
                        type: .statusUpdate,
                        isRead: false,
                        createdAt: Date()
                    )
                )
                await MainActor.run {
                    onSave()
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveErrorMessage = error.localizedDescription
                    showSaveError = true
                }
            }
        }
    }
}

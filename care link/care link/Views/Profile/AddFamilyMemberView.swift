import SwiftUI
import FirebaseAuth

struct AddFamilyMemberView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var fullName = ""
    @State private var relation = "Parent"
    @State private var dateOfBirth = Date()
    @State private var notes = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    let onSave: (FamilyMember) -> Void

    private let relations = ["Parent", "Spouse", "Child", "Sibling", "Grandparent", "Other"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CLTheme.spacingLG) {
                    Text("Create a New Profile")
                        .font(CLTheme.titleFont)
                        .foregroundStyle(CLTheme.textPrimary)
                    Text("Add a family member so caregivers can support them better.")
                        .font(CLTheme.bodyFont)
                        .foregroundStyle(CLTheme.textSecondary)

                    CLCard {
                        VStack(spacing: CLTheme.spacingMD) {
                            field(title: "FULL NAME") {
                                CLTextField(placeholder: "Enter full name", text: $fullName, icon: "person.fill")
                            }
                            field(title: "RELATION") {
                                Picker("Relation", selection: $relation) {
                                    ForEach(relations, id: \.self) { item in
                                        Text(item).tag(item)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            field(title: "DATE OF BIRTH") {
                                DatePicker("Date of Birth", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
                                    .datePickerStyle(.compact)
                            }
                            field(title: "HEALTH NOTES") {
                                TextEditor(text: $notes)
                                    .frame(minHeight: 100)
                                    .padding(CLTheme.spacingSM)
                                    .background(CLTheme.backgroundSecondary)
                                    .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusMD))
                            }
                        }
                    }

                    CLButton(title: "Save Member", icon: "person.badge.plus", isLoading: isSaving) {
                        saveMember()
                    }
                    CLButton(title: "Cancel", style: .text) {
                        dismiss()
                    }

                    HStack(spacing: CLTheme.spacingSM) {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(CLTheme.tealAccent)
                        Text("All information is encrypted and shared only with authorized healthcare providers.")
                            .font(CLTheme.captionFont)
                            .foregroundStyle(CLTheme.textSecondary)
                    }
                    .padding(CLTheme.spacingMD)
                    .background(CLTheme.tealAccent.opacity(0.08))
                    .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusMD))
                }
                .padding(CLTheme.spacingMD)
            }
            .background(CLTheme.backgroundPrimary)
            .navigationTitle("Add Family Member")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Unable to Save", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    @ViewBuilder
    private func field<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
            Text(title)
                .font(CLTheme.smallFont)
                .foregroundStyle(CLTheme.textTertiary)
                .tracking(1)
            content()
        }
    }

    private func saveMember() {
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter the member name."
            showError = true
            return
        }
        let ownerId = appState.authService.currentUser?.uid ?? ""
        guard !ownerId.isEmpty else {
            errorMessage = "Please sign in again."
            showError = true
            return
        }

        isSaving = true
        let member = FamilyMember(
            id: "fm_\(UUID().uuidString.prefix(10).lowercased())",
            ownerUserId: ownerId,
            fullName: trimmed,
            relation: relation,
            dateOfBirth: dateOfBirth,
            healthNotes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            photoURL: "",
            createdAt: Date()
        )

        Task {
            do {
                try await appState.firestoreService.addFamilyMember(member)
                await MainActor.run {
                    onSave(member)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isSaving = false
                }
            }
        }
    }
}


import SwiftUI
import FirebaseAuth

struct MedicalRecordsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let patientId: String
    let patientName: String
    var startInAddMode: Bool = false

    @State private var records: [MedicalRecord] = []
    @State private var isLoading = true
    @State private var showAddRecord = false
    @State private var selectedType: MedicalRecord.RecordType?
    @State private var didAutoPresentAdd = false
    @State private var loadErrorMessage: String?

    private var isCaregiver: Bool {
        appState.currentUserRole == .caregiver
    }

    private var filteredRecords: [MedicalRecord] {
        guard let type = selectedType else { return records }
        return records.filter { $0.recordType == type }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            filterChips

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadErrorMessage {
                VStack(spacing: CLTheme.spacingMD) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(CLTheme.warningOrange)
                    Text("Could not load records")
                        .font(CLTheme.headlineFont)
                        .foregroundStyle(CLTheme.textPrimary)
                    Text(loadErrorMessage)
                        .font(CLTheme.captionFont)
                        .foregroundStyle(CLTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, CLTheme.spacingXL)
                    Button("Try again") {
                        Task { await loadRecords() }
                    }
                    .font(CLTheme.calloutFont.weight(.semibold))
                    Spacer()
                }
            } else if filteredRecords.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: CLTheme.spacingMD) {
                        ForEach(filteredRecords) { record in
                            recordCard(record)
                        }
                    }
                    .padding(.horizontal, CLTheme.spacingMD)
                    .padding(.bottom, 100)
                }
            }
        }
        .background(CLTheme.backgroundPrimary)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(CLTheme.textPrimary)
                }
            }
            if isCaregiver {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddRecord = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(CLTheme.accentBlue)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddRecord) {
            AddMedicalRecordView(patientId: patientId, patientName: patientName) {
                Task { await loadRecords() }
            }
            .environment(appState)
        }
        .task {
            await loadRecords()
        }
        .onAppear {
            if startInAddMode, isCaregiver, !didAutoPresentAdd {
                didAutoPresentAdd = true
                showAddRecord = true
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
            Text("Medical Records")
                .font(CLTheme.titleFont)
                .foregroundStyle(CLTheme.textPrimary)

            HStack(spacing: CLTheme.spacingSM) {
                Circle()
                    .fill(CLTheme.primaryNavy.opacity(0.12))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Text(String(patientName.prefix(2)).uppercased())
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(CLTheme.primaryNavy)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(patientName)
                        .font(CLTheme.headlineFont)
                        .foregroundStyle(CLTheme.textPrimary)
                    Text("\(records.count) records")
                        .font(CLTheme.captionFont)
                        .foregroundStyle(CLTheme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, CLTheme.spacingMD)
        .padding(.vertical, CLTheme.spacingSM)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CLTheme.spacingSM) {
                CLChip(title: "All", isSelected: selectedType == nil) {
                    selectedType = nil
                }
                ForEach(MedicalRecord.RecordType.allCases, id: \.self) { type in
                    CLChip(title: type.rawValue, isSelected: selectedType == type) {
                        selectedType = type
                    }
                }
            }
            .padding(.horizontal, CLTheme.spacingMD)
        }
        .padding(.bottom, CLTheme.spacingSM)
    }

    private func recordCard(_ record: MedicalRecord) -> some View {
        CLCard {
            VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color(hex: record.recordType.colorHex).opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: record.recordType.iconName)
                            .font(.system(size: 16))
                            .foregroundStyle(Color(hex: record.recordType.colorHex))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.title)
                            .font(CLTheme.headlineFont)
                            .foregroundStyle(CLTheme.textPrimary)
                        Text(record.recordType.rawValue)
                            .font(CLTheme.captionFont)
                            .foregroundStyle(Color(hex: record.recordType.colorHex))
                    }

                    Spacer()

                    Text(record.date.formatted(date: .abbreviated, time: .omitted))
                        .font(CLTheme.captionFont)
                        .foregroundStyle(CLTheme.textTertiary)
                }

                Text(record.recordDescription)
                    .font(CLTheme.bodyFont)
                    .foregroundStyle(CLTheme.textSecondary)
                    .lineLimit(3)

                if !record.notes.isEmpty {
                    HStack(spacing: CLTheme.spacingSM) {
                        Image(systemName: "note.text")
                            .font(.system(size: 12))
                            .foregroundStyle(CLTheme.textTertiary)
                        Text(record.notes)
                            .font(CLTheme.captionFont)
                            .foregroundStyle(CLTheme.textTertiary)
                            .lineLimit(2)
                    }
                    .padding(CLTheme.spacingSM)
                    .background(CLTheme.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusSM))
                }

                HStack {
                    Label("By \(record.caregiverName)", systemImage: "person.fill")
                        .font(CLTheme.captionFont)
                        .foregroundStyle(CLTheme.textTertiary)
                    Spacer()
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: CLTheme.spacingMD) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(CLTheme.textTertiary)
            Text("No medical records")
                .font(CLTheme.headlineFont)
                .foregroundStyle(CLTheme.textSecondary)
            if isCaregiver {
                Text("Tap + to add the first record for this patient.")
                    .font(CLTheme.bodyFont)
                    .foregroundStyle(CLTheme.textTertiary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
    }

    private func loadRecords() async {
        do {
            if isCaregiver {
                records = try await appState.firestoreService.fetchMedicalRecordsForCaregiverPatient(patientId)
            } else {
                records = try await appState.firestoreService.fetchMedicalRecordsForPatient(patientId)
            }
            loadErrorMessage = nil
        } catch {
            records = []
            loadErrorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

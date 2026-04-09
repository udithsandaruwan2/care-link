import SwiftUI
import FirebaseAuth

struct FamilyMembersView: View {
    @Environment(AppState.self) private var appState
    @State private var members: [FamilyMember] = []
    @State private var showAddMember = false
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
                header
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, CLTheme.spacingLG)
                } else if members.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: CLTheme.spacingMD) {
                        ForEach(members) { member in
                            memberCard(member)
                        }
                    }
                }
                privacyBanner
            }
            .padding(.horizontal, CLTheme.spacingMD)
            .padding(.bottom, 90)
        }
        .background(CLTheme.backgroundPrimary)
        .navigationTitle("Family Well-being")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddMember = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showAddMember) {
            AddFamilyMemberView { newMember in
                members.insert(newMember, at: 0)
            }
            .environment(appState)
        }
        .task {
            await loadMembers()
        }
    }

    private var header: some View {
        CLCard {
            VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                Text("Your Care Circle")
                    .font(CLTheme.smallFont)
                    .foregroundStyle(CLTheme.textTertiary)
                    .tracking(1)
                Text("Family Well-being")
                    .font(CLTheme.title2Font)
                    .foregroundStyle(CLTheme.textPrimary)
                Text("Manage health profiles and share relevant details with your care team.")
                    .font(CLTheme.calloutFont)
                    .foregroundStyle(CLTheme.textSecondary)
                CLButton(title: "Add Family Member", icon: "person.badge.plus") {
                    showAddMember = true
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: CLTheme.spacingMD) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 38))
                .foregroundStyle(CLTheme.textTertiary)
            Text("No family profiles yet")
                .font(CLTheme.headlineFont)
                .foregroundStyle(CLTheme.textPrimary)
            Text("Add your first family member to track visits and records.")
                .font(CLTheme.bodyFont)
                .foregroundStyle(CLTheme.textSecondary)
                .multilineTextAlignment(.center)
            CLButton(title: "Add Member", style: .outline) {
                showAddMember = true
            }
        }
        .frame(maxWidth: .infinity)
        .padding(CLTheme.spacingXL)
        .background(CLTheme.cardBackground)
        .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusLG))
    }

    private func memberCard(_ member: FamilyMember) -> some View {
        CLCard {
            VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
                HStack(spacing: CLTheme.spacingMD) {
                    Circle()
                        .fill(CLTheme.primaryNavy.opacity(0.12))
                        .frame(width: 52, height: 52)
                        .overlay {
                            Text(String(member.fullName.prefix(2)).uppercased())
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(CLTheme.primaryNavy)
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.fullName)
                            .font(CLTheme.headlineFont)
                            .foregroundStyle(CLTheme.textPrimary)
                        Text("\(member.relation) • \(member.age) years old")
                            .font(CLTheme.captionFont)
                            .foregroundStyle(CLTheme.textSecondary)
                    }
                    Spacer()
                }

                if !member.healthNotes.isEmpty {
                    Text(member.healthNotes)
                        .font(CLTheme.calloutFont)
                        .foregroundStyle(CLTheme.textSecondary)
                        .lineLimit(2)
                }
            }
        }
    }

    private var privacyBanner: some View {
        HStack(spacing: CLTheme.spacingSM) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(CLTheme.tealAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Privacy is our priority")
                    .font(CLTheme.calloutFont.weight(.semibold))
                    .foregroundStyle(CLTheme.tealAccent)
                Text("Family health details stay encrypted and visible only to authorized care providers.")
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.textSecondary)
            }
            Spacer()
        }
        .padding(CLTheme.spacingMD)
        .background(CLTheme.tealAccent.opacity(0.1))
        .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusMD))
    }

    private func loadMembers() async {
        let userId = appState.authService.currentUser?.uid ?? ""
        guard !userId.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        members = (try? await appState.firestoreService.fetchFamilyMembers(for: userId)) ?? []
    }
}

#Preview {
    NavigationStack {
        FamilyMembersView()
            .environment(AppState())
    }
}

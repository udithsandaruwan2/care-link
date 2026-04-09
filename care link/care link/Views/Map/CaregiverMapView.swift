import SwiftUI
import MapKit

struct CaregiverMapView: View {
    @Environment(AppState.self) private var appState
    @Binding var suppressMainTabBar: Bool
    @State private var viewModel = MapViewModel()
    @State private var showCaregiverProfile = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Map(position: $viewModel.cameraPosition) {
                    ForEach(viewModel.caregivers) { caregiver in
                        Annotation(
                            caregiver.name.components(separatedBy: " ").first ?? "",
                            coordinate: CLLocationCoordinate2D(
                                latitude: caregiver.latitude,
                                longitude: caregiver.longitude
                            )
                        ) {
                            mapPin(for: caregiver)
                        }
                    }

                    UserAnnotation()
                }
                .mapStyle(.standard)
                .ignoresSafeArea()

                // Top chrome only (intrinsic height) so the map stays tappable below the card.
                VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                    searchOverlay

                    if let selected = viewModel.selectedCaregiver {
                        caregiverDetailCard(selected)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                if viewModel.caregivers.isEmpty && !viewModel.isLoading {
                    VStack {
                        Spacer()
                        noCaregiversBanner
                            .padding(.horizontal, CLTheme.spacingMD)
                            .padding(.bottom, emptyStateBottomInset)
                    }
                    .allowsHitTesting(false)
                }
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showCaregiverProfile) {
                if let caregiver = viewModel.selectedCaregiver {
                    CaregiverProfileView(caregiver: caregiver)
                        .environment(appState)
                }
            }
            .task {
                await viewModel.loadCaregivers(firestoreService: appState.firestoreService)
                appState.locationService.requestPermission()
            }
            .onAppear { syncMainTabBarVisibility() }
            .onChange(of: showCaregiverProfile) { _, _ in syncMainTabBarVisibility() }
            .onChange(of: viewModel.selectedCaregiver?.id) { _, _ in syncMainTabBarVisibility() }
        }
    }

    /// Bottom inset so the empty-state banner clears the floating tab bar when it is shown.
    private var emptyStateBottomInset: CGFloat {
        if showCaregiverProfile { return CLTheme.spacingLG }
        if viewModel.selectedCaregiver != nil { return CLTheme.spacingLG }
        return 100
    }

    private func syncMainTabBarVisibility() {
        suppressMainTabBar = showCaregiverProfile || viewModel.selectedCaregiver != nil
    }

    private func mapPin(for caregiver: Caregiver) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                viewModel.selectCaregiver(caregiver)
            }
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(caregiver.isVerified ? CLTheme.tealAccent : CLTheme.warningOrange)
                        .frame(width: 40, height: 40)
                        .shadow(color: CLTheme.shadowMedium, radius: 4)

                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }

                Text(caregiver.name.components(separatedBy: " ").first?.uppercased() ?? "")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(CLTheme.primaryNavy)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.white)
                    .clipShape(Capsule())
                    .shadow(color: CLTheme.shadowLight, radius: 2)
            }
        }
    }

    private var searchOverlay: some View {
        HStack(spacing: CLTheme.spacingSM) {
            HStack(spacing: CLTheme.spacingSM) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(CLTheme.textTertiary)
                TextField("Search caregivers nearby...", text: $viewModel.searchText)
                    .font(CLTheme.bodyFont)
            }
            .padding(.horizontal, CLTheme.spacingMD)
            .frame(height: 48)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusFull))

            Button {
                if let coordinate = appState.locationService.userLocation {
                    viewModel.centerOnUserLocation(coordinate)
                }
            } label: {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(CLTheme.primaryNavy)
            }
        }
        .padding(.horizontal, CLTheme.spacingMD)
        .padding(.top, CLTheme.spacingSM)
    }

    private var noCaregiversBanner: some View {
        HStack(spacing: CLTheme.spacingSM) {
            Image(systemName: "mappin.slash")
                .foregroundStyle(CLTheme.textTertiary)
            Text("No caregivers registered in this area yet")
                .font(CLTheme.calloutFont)
                .foregroundStyle(CLTheme.textSecondary)
        }
        .padding(CLTheme.spacingMD)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD))
        .padding(.horizontal, CLTheme.spacingMD)
        .padding(.bottom, CLTheme.spacingMD)
    }

    private func caregiverDetailCard(_ caregiver: Caregiver) -> some View {
        CLCard {
            VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                HStack(alignment: .top) {
                    Text("Selected caregiver")
                        .font(CLTheme.smallFont)
                        .foregroundStyle(CLTheme.textTertiary)
                        .tracking(0.5)
                    Spacer()
                    Button {
                        viewModel.clearCaregiverSelection()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(CLTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss")
                }

                HStack(spacing: CLTheme.spacingMD) {
                    CaregiverAvatar(size: 65, imageURL: caregiver.imageURL, showVerified: caregiver.isVerified)

                    VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                        HStack {
                            Text(caregiver.name)
                                .font(CLTheme.headlineFont)
                                .foregroundStyle(CLTheme.textPrimary)
                            Spacer()
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(CLTheme.starYellow)
                                Text(String(format: "%.1f", caregiver.rating))
                                    .font(CLTheme.calloutFont)
                                    .foregroundStyle(CLTheme.textPrimary)
                            }
                        }

                        Text(caregiver.specialty)
                            .font(CLTheme.captionFont)
                            .foregroundStyle(CLTheme.textSecondary)

                        HStack {
                            Text("$\(String(format: "%.0f", caregiver.hourlyRate))/hr")
                                .font(CLTheme.calloutFont)
                                .foregroundStyle(CLTheme.tealAccent)

                            Spacer()

                            Button {
                                showCaregiverProfile = true
                            } label: {
                                Text("View profile")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(CLTheme.primaryNavy)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, CLTheme.spacingMD)
        .shadow(color: CLTheme.shadowMedium.opacity(0.2), radius: 12, y: 4)
    }
}

#Preview {
    CaregiverMapView(suppressMainTabBar: .constant(false))
        .environment(AppState())
}

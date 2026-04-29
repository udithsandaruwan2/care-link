import SwiftUI

struct CLNavigationBar: View {
    var showBackButton: Bool = false
    var title: String? = nil
    var showFilterButton: Bool = true
    var backAction: (() -> Void)? = nil
    var filterAction: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(CLTheme.backgroundPrimary)
                .shadow(color: CLTheme.shadowLight, radius: 8, y: 4)

            HStack {
                if showBackButton {
                    Button {
                        backAction?()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(CLTheme.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(CLTheme.backgroundSecondary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: CLTheme.spacingSM) {
                        Image(systemName: "cross.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(CLTheme.primaryNavy)
                        Text("CareLink")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(CLTheme.primaryNavy)
                    }
                }

                if let title {
                    Spacer()
                    Text(title)
                        .font(CLTheme.title2Font)
                        .foregroundStyle(CLTheme.textPrimary)
                }

                Spacer()

                if showFilterButton {
                    Button {
                        filterAction?()
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(CLTheme.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(CLTheme.backgroundSecondary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open filters")
                }
            }
            .padding(.horizontal, CLTheme.spacingMD)
            .padding(.vertical, CLTheme.spacingSM)

            Rectangle()
                .fill(CLTheme.divider.opacity(0.5))
                .frame(height: 0.5)
        }
        .frame(height: 62)
        .clipped()
    }
}

#Preview {
    VStack {
        CLNavigationBar()
        Divider()
        CLNavigationBar(showBackButton: true, title: "Caregiver Profile")
    }
}

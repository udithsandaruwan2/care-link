import SwiftUI

struct CLNavigationBar: View {
    var showBackButton: Bool = false
    var title: String? = nil
    var showFilterButton: Bool = true
    var backAction: (() -> Void)? = nil
    var filterAction: (() -> Void)? = nil

    var body: some View {
        HStack {
            if showBackButton {
                Button {
                    backAction?()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(CLTheme.textPrimary)
                }
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
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18))
                        .foregroundStyle(CLTheme.textPrimary)
                }
            }
        }
        .padding(.horizontal, CLTheme.spacingMD)
        .padding(.vertical, CLTheme.spacingSM)
    }
}

#Preview {
    VStack {
        CLNavigationBar()
        Divider()
        CLNavigationBar(showBackButton: true, title: "Caregiver Profile")
    }
}

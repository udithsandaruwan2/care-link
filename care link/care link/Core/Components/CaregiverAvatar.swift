// File responsibility: Defines caregiver avatar logic for the care link app.

import SwiftUI

struct CaregiverAvatar: View {
    var size: CGFloat = 60
    var imageURL: String = ""
    var showVerified: Bool = false
    /// Used for VoiceOver when the avatar represents a person.
    var accessibilityName: String? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [CLTheme.lightBlue, CLTheme.backgroundSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(CLTheme.primaryNavy.opacity(0.6))
                }

            if showVerified {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: size * 0.25))
                    .foregroundStyle(CLTheme.tealAccent)
                    .background(
                        Circle()
                            .fill(.white)
                            .frame(width: size * 0.28, height: size * 0.28)
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(avatarAccessibilityLabel)
        .accessibilityAddTraits(.isImage)
    }

    private var avatarAccessibilityLabel: String {
        let base = accessibilityName ?? String(localized: "Caregiver profile photo")
        if showVerified {
            return base + ", " + String(localized: "Verified caregiver")
        }
        return base
    }
}

#Preview {
    HStack(spacing: 20) {
        CaregiverAvatar(size: 50, showVerified: true)
        CaregiverAvatar(size: 70, showVerified: false)
        CaregiverAvatar(size: 90, showVerified: true)
    }
}

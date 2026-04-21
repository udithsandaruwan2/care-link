import SwiftUI

struct SupportCenterView: View {
    @Environment(\.openURL) private var openURL

    @State private var name = ""
    @State private var email = ""
    @State private var message = ""
    @State private var showSentBanner = false

    private let supportEmail = "support@carelink.app"
    private let facebookSupportURL = "https://www.facebook.com/carelink.support"

    private let faqs: [(question: String, answer: String)] = [
        ("How do I book a caregiver?", "Go to Home, choose a caregiver, select date/time, then confirm your request."),
        ("How can a caregiver add medical records?", "Open the patient profile from dashboard, then tap Medical Records and use the + button."),
        ("Why is my booking still pending?", "Pending means the caregiver has not accepted yet. You can cancel from your booking details or care hub."),
        ("How do I reset biometric login?", "Open Settings, turn Biometric Login off, then on again and re-authenticate.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLTheme.spacingLG) {
                contactMethods
                faqSection
                requestForm
            }
            .padding(CLTheme.spacingMD)
            .padding(.bottom, 40)
        }
        .background(CLTheme.backgroundPrimary)
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if showSentBanner {
                Text("Support request prepared. Please send from Mail.")
                    .font(CLTheme.captionFont)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(CLTheme.successGreen)
                    .clipShape(Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var contactMethods: some View {
        CLCard {
            VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
                Text("Contact us")
                    .font(CLTheme.title2Font)
                    .foregroundStyle(CLTheme.textPrimary)

                Button {
                    if let url = URL(string: "mailto:\(supportEmail)") {
                        openURL(url)
                    }
                } label: {
                    supportRow(icon: "envelope.fill", title: "Email Support", subtitle: supportEmail)
                }
                .buttonStyle(.plain)

                Button {
                    if let url = URL(string: facebookSupportURL) {
                        openURL(url)
                    }
                } label: {
                    supportRow(icon: "message.fill", title: "Ask on Facebook", subtitle: "facebook.com/carelink.support")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var faqSection: some View {
        CLCard {
            VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                Text("Q&A")
                    .font(CLTheme.title2Font)
                    .foregroundStyle(CLTheme.textPrimary)

                ForEach(Array(faqs.enumerated()), id: \.offset) { _, item in
                    DisclosureGroup(item.question) {
                        Text(item.answer)
                            .font(CLTheme.bodyFont)
                            .foregroundStyle(CLTheme.textSecondary)
                            .padding(.top, 4)
                    }
                    .font(CLTheme.calloutFont)
                    .tint(CLTheme.primaryNavy)
                }
            }
        }
    }

    private var requestForm: some View {
        CLCard {
            VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
                Text("Send support request")
                    .font(CLTheme.title2Font)
                    .foregroundStyle(CLTheme.textPrimary)

                CLTextField(placeholder: "Your name", text: $name, icon: "person.fill")
                CLTextField(placeholder: "Your email", text: $email, icon: "envelope.fill")

                TextEditor(text: $message)
                    .font(CLTheme.bodyFont)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(CLTheme.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD, style: .continuous))

                CLButton(title: "Send Request", icon: "paperplane.fill") {
                    sendRequest()
                }
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func supportRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: CLTheme.spacingMD) {
            Image(systemName: icon)
                .foregroundStyle(CLTheme.accentBlue)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CLTheme.headlineFont)
                    .foregroundStyle(CLTheme.textPrimary)
                Text(subtitle)
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(CLTheme.textTertiary)
        }
    }

    private func sendRequest() {
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanMessage.isEmpty else { return }
        let subject = "CareLink Support Request"
        let body = """
        Name: \(name.isEmpty ? "Not provided" : name)
        Email: \(email.isEmpty ? "Not provided" : email)

        Message:
        \(cleanMessage)
        """
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
        if let url = URL(string: "mailto:\(supportEmail)?subject=\(encodedSubject)&body=\(encodedBody)") {
            openURL(url)
            withAnimation {
                showSentBanner = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showSentBanner = false
                }
            }
        }
    }
}


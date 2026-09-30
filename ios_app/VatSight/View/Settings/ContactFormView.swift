//
//  ContactFormView.swift
//  VatSight
//
//  Created by Marcel Marzec on 30/09/2026.
//

import SwiftUI
import MessageUI

// MARK: - Reason Type

enum ContactReasonType: String, CaseIterable, Identifiable {
    case bugReport = "Bug Report"
    case featureRequest = "Feature Request"
    case sectorATCIssue = "Sector / ATC Issue"
    case generalFeedback = "General Feedback"
    case other = "Other"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .bugReport: return "ant.fill"
        case .featureRequest: return "lightbulb.fill"
        case .sectorATCIssue: return "antenna.radiowaves.left.and.right"
        case .generalFeedback: return "bubble.left.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Mail Compose View (UIViewControllerRepresentable)

struct MailComposeView: UIViewControllerRepresentable {
    let subject: String
    let body: String
    @Binding var isPresented: Bool
    var onSent: (() -> Void)? = nil

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var isPresented: Bool
        var onSent: (() -> Void)?

        init(isPresented: Binding<Bool>, onSent: (() -> Void)?) {
            _isPresented = isPresented
            self.onSent = onSent
        }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            isPresented = false
            if result == .sent {
                onSent?()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onSent: onSent)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(["contact@marcelmarzec.com"])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: true)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}

// MARK: - Contact Form View

struct ContactFormView: View {
    @EnvironmentObject private var radarViewModel: RadarViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedReason: ContactReasonType = .generalFeedback
    @State private var emailSubject: String = ""
    @State private var details: String = ""
    @State private var atcSectorReference: String = ""

    @State private var showMailCompose = false
    @State private var showMailUnavailableAlert = false

    private enum Field { case subject, details, atcSector }
    @FocusState private var focusedField: Field?

    private var isSubmitEnabled: Bool {
        !emailSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var mailSubject: String {
        "VS \(emailSubject.trimmingCharacters(in: .whitespacesAndNewlines)) - \(selectedReason.rawValue)"
    }

    private var mailBody: String {
        buildEmailBody()
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Reason section
                Section {
                    Picker("Reason", selection: $selectedReason) {
                        ForEach(ContactReasonType.allCases) { reason in
                            Label(reason.rawValue, systemImage: reason.systemImage).tag(reason)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("What can we help you with?")
                }

                // MARK: Subject section
                Section {
                    TextField("Brief summary of your message", text: $emailSubject)
                        .focused($focusedField, equals: .subject)
                } header: {
                    Text("Subject")
                }

                // MARK: Details section
                Section {
                    ZStack(alignment: .topLeading) {
                        if details.isEmpty {
                            Text("Describe your issue or feedback...")
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $details)
                            .focused($focusedField, equals: .details)
                            .frame(minHeight: 120)
                    }
                } header: {
                    Text("Details")
                } footer: {
                    Text("Please provide as much detail as possible.")
                }

                // MARK: ATC / Sector reference (only shown for Sector/ATC Issue)
                if selectedReason == .sectorATCIssue {
                    Section {
                        TextField("e.g. EGTT_W_CTR, London Control", text: $atcSectorReference)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                            .focused($focusedField, equals: .atcSector)
                    } header: {
                        Text("ATC Position / Sector")
                    } footer: {
                        Text("Enter the callsign or name of the affected ATC position or sector.")
                    }
                }

                // MARK: Submit section
                Section {
                    Button {
                        submitForm()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Submit")
                                .bold()
                            Spacer()
                        }
                    }
                    .disabled(!isSubmitEnabled)
                } footer: {
                    Text("This will open your Mail app with a pre-filled message to the VatSight developer.")
                }
            }
            .navigationTitle("Get in Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .sheet(isPresented: $showMailCompose) {
                MailComposeView(
                    subject: mailSubject,
                    body: mailBody,
                    isPresented: $showMailCompose,
                    onSent: { dismiss() }
                )
                .ignoresSafeArea()
            }
            .alert("Mail Unavailable", isPresented: $showMailUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("No mail account is configured on this device. Please email contact@marcelmarzec.com directly.")
            }
        }
    }

    // MARK: - Form Submission

    private func submitForm() {
        guard MFMailComposeViewController.canSendMail() else {
            showMailUnavailableAlert = true
            return
        }
        showMailCompose = true
    }

    private func buildEmailBody() -> String {
        var html = """
        <html>
        <body style="font-family: -apple-system, Helvetica Neue, Arial, sans-serif; color: #1c1c1e; font-size: 15px;">
        <h2 style="color: #0071e3;">VatSight Support Request</h2>
        <table style="border-collapse: collapse; width: 100%; max-width: 600px;">
          <tr>
            <td style="padding: 8px 12px; font-weight: bold; white-space: nowrap;">Reason</td>
            <td style="padding: 8px 12px;">\(selectedReason.rawValue)</td>
          </tr>
        """

        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            html += """
              <tr>
                <td style="padding: 8px 12px; font-weight: bold; white-space: nowrap;">App Version</td>
                <td style="padding: 8px 12px;">\(version) (\(build))</td>
              </tr>
            """
        }

        html += """
        </table>
        <hr style="border: none; border-top: 1px solid #d1d1d6; margin: 16px 0;">
        <h3>Details</h3>
        <p style="white-space: pre-wrap; background: #2c2c2e; color: #f2f2f7; padding: 12px; border-radius: 8px;">\(details.htmlEscaped)</p>
        """

        // ATC / Sector reference — only included when reason is Sector/ATC Issue
        let trimmedRef = atcSectorReference.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedReason == .sectorATCIssue && !trimmedRef.isEmpty {
            html += "<hr style=\"border: none; border-top: 1px solid #d1d1d6; margin: 16px 0;\">"
            html += "<h3>Referenced ATC Position / Sector</h3>"
            html += "<p>\(trimmedRef.htmlEscaped)</p>"
        }

        html += """
        <hr style="border: none; border-top: 1px solid #d1d1d6; margin: 16px 0;">
        <p style="color: #8e8e93; font-size: 12px;">Sent via VatSight iOS App</p>
        </body>
        </html>
        """

        return html
    }
}

// MARK: - Preview

#Preview {
    ContactFormView()
        .environmentObject(RadarViewModel())
}

// MARK: - String HTML Escaping

private extension String {
    var htmlEscaped: String {
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

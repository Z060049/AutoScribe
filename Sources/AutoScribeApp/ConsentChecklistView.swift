import AppKit
import AutoScribeCore
import SwiftUI

struct ConsentChecklistView: View {
    @ObservedObject var controller: AutoScribeController
    @State private var understandsConsent = false
    @State private var understandsIndicator = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Before recording")
                .font(.headline)

            Text("Recording laws vary by location. Only record conversations when you have the required consent.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            accessibilityPermissionSection

            Toggle("I understand I am responsible for consent.", isOn: $understandsConsent)
            Toggle("I understand AutoScribe shows recording state while active.", isOn: $understandsIndicator)

            Button("Accept and Continue") {
                controller.acceptConsentChecklist()
            }
            .disabled(!understandsConsent || !understandsIndicator)
        }
    }

    private var accessibilityPermissionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: controller.isAccessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(controller.isAccessibilityTrusted ? .green : .orange)
                Text("Keyboard Shortcut Permission")
                    .font(.headline)
            }

            Text("AutoScribe needs Accessibility permission to detect double-tap Command while you are in another app.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Request Permission") {
                    controller.requestAccessibilityPermissionPrompt()
                }

                Button("Open Settings") {
                    NSWorkspace.shared.open(AccessibilityPermissionService.settingsURL)
                }

                Button("Refresh") {
                    controller.refreshAccessibilityPermissionStatus()
                }
            }

            Text(controller.isAccessibilityTrusted ? "Permission granted." : "Permission not granted yet. You can still use Start Recording from the menu.")
                .font(.caption)
                .foregroundStyle(controller.isAccessibilityTrusted ? .green : .orange)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

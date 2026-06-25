import AutoScribeCore
import SwiftUI

struct MenuBarRootView: View {
    @ObservedObject var controller: AutoScribeController
    @State private var showingSettings = false
    @State private var showingDiagnostics = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if !controller.settings.hasAcceptedConsentChecklist {
                ConsentChecklistView(controller: controller)
            } else {
                shortcutPermissionStatus
                controls
            }

            if let error = controller.lastError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Button("Settings") {
                showingSettings = true
            }

            DisclosureGroup("Debug", isExpanded: $showingDiagnostics) {
                DiagnosticsView(controller: controller)
                    .padding(.top, 6)
            }

            Button("Quit AutoScribe") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 460)
        .sheet(isPresented: $showingSettings) {
            SettingsView(controller: controller)
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: controller.state.menuBarSymbolName)
                .foregroundStyle(controller.state.isRecording ? .red : .primary)
            VStack(alignment: .leading) {
                Text("AutoScribe")
                    .font(.headline)
                Text(controller.state.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(controller.state.isRecording ? "Stop Recording" : "Start Recording") {
                controller.toggleRecording()
            }
            .keyboardShortcut(.defaultAction)

            Text("Double-tap Command from anywhere to start or stop.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if case .complete(let url) = controller.state {
                Text("Saved: \(url.path)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var shortcutPermissionStatus: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: controller.isAccessibilityTrusted ? "keyboard.badge.checkmark" : "keyboard.badge.ellipsis")
                .foregroundStyle(controller.isAccessibilityTrusted ? .green : .orange)

            VStack(alignment: .leading, spacing: 6) {
                Text(controller.isAccessibilityTrusted ? "Double-Command shortcut enabled" : "Double-Command shortcut needs Accessibility permission")
                    .font(.caption)
                    .foregroundStyle(controller.isAccessibilityTrusted ? Color.secondary : Color.orange)

                if !controller.isAccessibilityTrusted {
                    HStack {
                        Button("Open Settings") {
                            NSWorkspace.shared.open(AccessibilityPermissionService.settingsURL)
                        }
                        Button("Refresh") {
                            controller.refreshAccessibilityPermissionStatus()
                        }
                    }
                }
            }
        }
    }
}

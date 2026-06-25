import AppKit
import AutoScribeCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: AutoScribeController
    @Environment(\.dismiss) private var dismiss

    @State private var settings: AppSettings
    @State private var apiKey: String = ""
    @State private var statusMessage: String?

    init(controller: AutoScribeController) {
        self.controller = controller
        _settings = State(initialValue: controller.settings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title2)
                .bold()

            Picker("Processing Mode", selection: $settings.processingMode) {
                Text("API").tag(ProcessingMode.api)
                Text("Local (later)").tag(ProcessingMode.local)
            }

            SecureField("OpenAI API Key", text: $apiKey)

            Picker("Summary Depth", selection: $settings.summaryDepth) {
                ForEach(SummaryDepth.allCases, id: \.self) { depth in
                    Text(depth.rawValue.capitalized).tag(depth)
                }
            }

            HStack {
                Text("Inactivity Timeout")
                TextField("Seconds", value: $settings.inactivityTimeoutSeconds, format: .number)
                    .frame(width: 80)
                Text("seconds")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Output Folder")
                Text(settings.outputDirectory.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Button("Choose Folder") {
                    chooseOutputFolder()
                }
            }

            Toggle("Show consent reminder before capture", isOn: $settings.shouldShowConsentReminder)

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 460)
        .task {
            apiKey = (try? controller.loadOpenAIAPIKey()) ?? ""
        }
    }

    private func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            settings.outputDirectory = url
        }
    }

    private func save() {
        do {
            controller.updateSettings(settings)
            if !apiKey.isEmpty {
                try controller.saveOpenAIAPIKey(apiKey)
            }
            statusMessage = "Settings saved."
            dismiss()
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

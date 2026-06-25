import Combine
import Foundation

public final class AutoScribeController: ObservableObject {
    @Published public private(set) var state: AppState = .idle
    @Published public private(set) var settings: AppSettings
    @Published public private(set) var lastError: String?
    @Published public private(set) var diagnostics: [DiagnosticEvent] = []
    @Published public private(set) var isAccessibilityTrusted: Bool

    private let settingsStore: SettingsStore
    private let keychainStore: KeychainStore
    private let audioCaptureService: DualAudioCaptureService
    private let markdownExporter: MarkdownExporter
    private var processingProvider: ProcessingProvider
    private var inactivityMonitor: InactivityMonitor?

    public init(
        settingsStore: SettingsStore = SettingsStore(),
        keychainStore: KeychainStore = KeychainStore(),
        audioCaptureService: DualAudioCaptureService = DualAudioCaptureService(),
        markdownExporter: MarkdownExporter = MarkdownExporter(),
        processingProvider: ProcessingProvider? = nil
    ) {
        self.settingsStore = settingsStore
        self.keychainStore = keychainStore
        self.audioCaptureService = audioCaptureService
        self.markdownExporter = markdownExporter
        self.settings = settingsStore.load()
        self.isAccessibilityTrusted = AccessibilityPermissionService.isTrusted
        self.processingProvider = processingProvider ?? OpenAIProcessingProvider {
            try keychainStore.load(account: "openai-api-key")
        }
        Task { @MainActor in
            self.addDiagnostic("Controller initialized. Output folder: \(self.settings.outputDirectory.path)")
        }
    }

    @MainActor public func updateSettings(_ settings: AppSettings) {
        self.settings = settings
        settingsStore.save(settings)
        addDiagnostic("Settings saved. Timeout: \(Int(settings.inactivityTimeoutSeconds))s, output: \(settings.outputDirectory.path)")
    }

    public func saveOpenAIAPIKey(_ apiKey: String) throws {
        try keychainStore.save(apiKey, account: "openai-api-key")
        Task { @MainActor in
            self.addDiagnostic("OpenAI API key saved to Keychain.")
        }
    }

    public func loadOpenAIAPIKey() throws -> String? {
        try keychainStore.load(account: "openai-api-key")
    }

    @MainActor public func refreshAccessibilityPermissionStatus() {
        isAccessibilityTrusted = AccessibilityPermissionService.isTrusted
        addDiagnostic(
            isAccessibilityTrusted
                ? "Accessibility permission is trusted."
                : "Accessibility permission is not trusted.",
            level: isAccessibilityTrusted ? .info : .warning
        )
    }

    @MainActor public func requestAccessibilityPermissionPrompt() {
        let trusted = AccessibilityPermissionService.requestPrompt()
        isAccessibilityTrusted = trusted
        addDiagnostic(
            trusted
                ? "Accessibility permission is trusted."
                : "Requested Accessibility permission prompt.",
            level: trusted ? .info : .warning
        )
    }

    @MainActor public func acceptConsentChecklist() {
        var updated = settings
        updated.hasAcceptedConsentChecklist = true
        updateSettings(updated)
        addDiagnostic("Consent checklist accepted.")
    }

    @MainActor public func toggleRecording() {
        if state.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    @MainActor public func startRecording() {
        addDiagnostic("Start recording requested.")
        guard settings.hasAcceptedConsentChecklist else {
            setState(.failed("Please accept the recording consent checklist before starting."))
            return
        }

        let session = RecordingSession(
            processingMode: settings.processingMode,
            outputDirectory: settings.outputDirectory
        )

        setState(.recording(session))
        lastError = nil

        Task {
            do {
                await configureInactivityMonitor()
                await MainActor.run {
                    self.addDiagnostic("Starting audio capture in \(session.temporaryDirectory.path)")
                }
                try await audioCaptureService.start(session: session)
                await MainActor.run {
                    self.addDiagnostic("Audio capture started.")
                }
            } catch {
                await MainActor.run {
                    self.fail(error)
                }
            }
        }
    }

    @MainActor public func stopRecording() {
        addDiagnostic("Stop recording requested.")
        Task {
            do {
                let result = try await audioCaptureService.stop()
                inactivityMonitor?.stop()
                inactivityMonitor = nil
                addDiagnostic("Audio capture stopped. Files: \(result.files.map { $0.url.lastPathComponent }.joined(separator: ", "))")
                for file in result.files {
                    addDiagnostic("\(file.source.rawValue) file size: \(Self.fileSizeDescription(for: file.url))")
                }
                await process(result)
            } catch {
                fail(error)
            }
        }
    }

    @MainActor private func process(_ capture: AudioCaptureResult) async {
        setState(.processing(capture.session))
        addDiagnostic("Processing started with \(capture.files.count) audio file(s).")

        do {
            let result = try await processingProvider.process(capture: capture, settings: settings)
            addDiagnostic("Processing complete. Exporting Markdown.")
            let outputURL = try markdownExporter.export(
                result: result,
                session: capture.session,
                to: settings.outputDirectory
            )
            cleanupTemporaryFiles(for: capture.session)
            setState(.complete(outputURL))
            addDiagnostic("Markdown saved to \(outputURL.path)")
        } catch {
            fail(error)
        }
    }

    @MainActor private func configureInactivityMonitor() async {
        let monitor = InactivityMonitor(timeout: settings.inactivityTimeoutSeconds) { [weak self] in
            Task { @MainActor in
                self?.addDiagnostic("Inactivity timeout reached. Stopping recording.", level: .warning)
                self?.stopRecording()
            }
        }

        audioCaptureService.setOnAudioLevel { [weak monitor] _, level in
            monitor?.recordAudioLevel(level)
        }

        monitor.start()
        inactivityMonitor = monitor
        addDiagnostic("Inactivity monitor started.")
    }

    private func cleanupTemporaryFiles(for session: RecordingSession) {
        do {
            try FileManager.default.removeItem(at: session.temporaryDirectory)
            Task { @MainActor in
                self.addDiagnostic("Temporary files cleaned up.")
            }
        } catch {
            Task { @MainActor in
                self.addDiagnostic("Temporary cleanup skipped: \(error.localizedDescription)", level: .warning)
            }
        }
    }

    @MainActor private func fail(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        lastError = message
        setState(.failed(message))
        addDiagnostic(message, level: .error)
        inactivityMonitor?.stop()
        inactivityMonitor = nil
    }

    @MainActor public func addDiagnostic(_ message: String, level: DiagnosticEvent.Level = .info) {
        diagnostics.append(DiagnosticEvent(level: level, message: message))
        if diagnostics.count > 100 {
            diagnostics.removeFirst(diagnostics.count - 100)
        }
    }

    @MainActor public func clearDiagnostics() {
        diagnostics.removeAll()
    }

    @MainActor private func setState(_ state: AppState) {
        self.state = state
        addDiagnostic("State changed to \(state.title).")
    }

    private static func fileSizeDescription(for url: URL) -> String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else {
            return "unknown"
        }
        return "\(size.intValue) bytes"
    }
}

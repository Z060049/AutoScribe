import Foundation

public final class DualAudioCaptureService: @unchecked Sendable {
    private let microphoneRecorder: MicrophoneRecorder
    private var systemAudioRecorder: Any?
    private var currentSession: RecordingSession?
    private var currentFiles: [CapturedAudioFile] = []

    public var onAudioLevel: ((AudioSource, Float) -> Void)? {
        didSet {
            microphoneRecorder.onAudioLevel = { [weak self] level in
                self?.onAudioLevel?(.microphone, level)
            }

            if #available(macOS 13.0, *),
               let recorder = systemAudioRecorder as? SystemAudioRecorder {
                recorder.onAudioLevel = { [weak self] level in
                    self?.onAudioLevel?(.systemAudio, level)
                }
            }
        }
    }

    public func setOnAudioLevel(_ handler: ((AudioSource, Float) -> Void)?) {
        onAudioLevel = handler
    }

    public init(microphoneRecorder: MicrophoneRecorder = MicrophoneRecorder()) {
        self.microphoneRecorder = microphoneRecorder
        if #available(macOS 13.0, *) {
            self.systemAudioRecorder = SystemAudioRecorder()
        }
    }

    public func start(session: RecordingSession) async throws {
        guard currentSession == nil else {
            throw AudioCaptureError.alreadyRecording
        }

        try FileManager.default.createDirectory(at: session.temporaryDirectory, withIntermediateDirectories: true)

        var files: [CapturedAudioFile] = []
        currentSession = session

        do {
            let microphoneURL = try await microphoneRecorder.start(in: session.temporaryDirectory)
            files.append(CapturedAudioFile(source: .microphone, url: microphoneURL))

            if #available(macOS 13.0, *),
               let recorder = systemAudioRecorder as? SystemAudioRecorder {
                let systemURL = try await recorder.start(in: session.temporaryDirectory)
                files.append(CapturedAudioFile(source: .systemAudio, url: systemURL))
            }

            currentFiles = files
        } catch {
            _ = try? microphoneRecorder.stop()
            if #available(macOS 13.0, *),
               let recorder = systemAudioRecorder as? SystemAudioRecorder {
                _ = try? await recorder.stop()
            }
            currentSession = nil
            currentFiles = []
            throw error
        }
    }

    public func stop() async throws -> AudioCaptureResult {
        guard let session = currentSession else {
            throw AudioCaptureError.notRecording
        }

        var files: [CapturedAudioFile] = []
        let microphoneURL = try microphoneRecorder.stop()
        files.append(CapturedAudioFile(source: .microphone, url: microphoneURL))

        if #available(macOS 13.0, *),
           let recorder = systemAudioRecorder as? SystemAudioRecorder {
            let systemURL = try await recorder.stop()
            files.append(CapturedAudioFile(source: .systemAudio, url: systemURL))
        }

        currentSession = nil
        currentFiles = []
        return AudioCaptureResult(session: session.finished, files: files)
    }
}

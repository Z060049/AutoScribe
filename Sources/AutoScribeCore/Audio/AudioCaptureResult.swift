import Foundation

public struct CapturedAudioFile: Equatable, Sendable {
    public let source: AudioSource
    public let url: URL

    public init(source: AudioSource, url: URL) {
        self.source = source
        self.url = url
    }
}

public struct AudioCaptureResult: Equatable, Sendable {
    public let session: RecordingSession
    public let files: [CapturedAudioFile]

    public init(session: RecordingSession, files: [CapturedAudioFile]) {
        self.session = session
        self.files = files
    }
}

public enum AudioCaptureError: Error, LocalizedError {
    case alreadyRecording
    case notRecording
    case microphonePermissionDenied
    case systemAudioPermissionDenied
    case noDisplayAvailable
    case writerUnavailable

    public var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            "Audio capture is already running."
        case .notRecording:
            "Audio capture is not running."
        case .microphonePermissionDenied:
            "Microphone permission was denied."
        case .systemAudioPermissionDenied:
            "System audio capture permission was denied."
        case .noDisplayAvailable:
            "No display was available for system audio capture."
        case .writerUnavailable:
            "The audio writer was not available."
        }
    }
}

import AVFoundation
import Foundation

public final class MicrophoneRecorder: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var outputURL: URL?

    public var onAudioLevel: ((Float) -> Void)?

    public init() {}

    public func start(in directory: URL) async throws -> URL {
        guard outputURL == nil else {
            throw AudioCaptureError.alreadyRecording
        }

        guard await requestMicrophoneAccess() else {
            throw AudioCaptureError.microphonePermissionDenied
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let url = directory.appendingPathComponent("microphone.wav")
        let file = try AVAudioFile(
            forWriting: url,
            settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: Int(format.channelCount),
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
        )

        input.installTap(onBus: 0, bufferSize: 4_096, format: format) { [weak self] buffer, _ in
            do {
                try file.write(from: buffer)
                self?.onAudioLevel?(buffer.rootMeanSquarePower)
            } catch {
                self?.onAudioLevel?(0)
            }
        }

        engine.prepare()
        try engine.start()

        audioFile = file
        outputURL = url
        return url
    }

    public func stop() throws -> URL {
        guard let outputURL else {
            throw AudioCaptureError.notRecording
        }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioFile = nil
        self.outputURL = nil
        return outputURL
    }

    private func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

private extension AVAudioPCMBuffer {
    var rootMeanSquarePower: Float {
        guard let channelData = floatChannelData, frameLength > 0 else {
            return 0
        }

        let frameCount = Int(frameLength)
        let channelCount = Int(format.channelCount)
        var sum: Float = 0

        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for frame in 0..<frameCount {
                let sample = samples[frame]
                sum += sample * sample
            }
        }

        let mean = sum / Float(max(frameCount * max(channelCount, 1), 1))
        return sqrt(mean)
    }
}

import Foundation

public protocol ProcessingProvider: Sendable {
    func process(capture: AudioCaptureResult, settings: AppSettings) async throws -> ProcessingResult
}

public enum ProcessingProviderError: Error, LocalizedError {
    case missingAPIKey
    case unsupportedLocalMode
    case invalidResponse
    case apiError(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Add an OpenAI API key in Settings before processing recordings."
        case .unsupportedLocalMode:
            "Local processing is planned after the API-first MVP."
        case .invalidResponse:
            "The processing provider returned an invalid response that AutoScribe could not parse."
        case .apiError(let message):
            message
        }
    }
}

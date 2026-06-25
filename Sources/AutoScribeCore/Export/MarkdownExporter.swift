import Foundation

public struct MarkdownDocument: Equatable, Sendable {
    public let filename: String
    public let contents: String

    public init(filename: String, contents: String) {
        self.filename = filename
        self.contents = contents
    }
}

public final class MarkdownExporter: @unchecked Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func export(
        result: ProcessingResult,
        session: RecordingSession,
        to directory: URL
    ) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let document = render(result: result, session: session)
        let outputURL = directory.appendingPathComponent(document.filename)
        try document.contents.write(to: outputURL, atomically: true, encoding: .utf8)
        return outputURL
    }

    public func render(result: ProcessingResult, session: RecordingSession) -> MarkdownDocument {
        let title = sanitizedTitle(result.summary.title)
        let filename = "\(Self.filenameDateFormatter.string(from: session.startedAt))_\(title).md"
        let sources = session.audioSources.map(\.rawValue).sorted().joined(separator: ", ")

        let contents = """
        ---
        title: \(result.summary.title)
        date: \(Self.metadataDateFormatter.string(from: session.startedAt))
        duration: \(Self.durationFormatter.string(from: session.duration) ?? "Unknown")
        processing_mode: \(session.processingMode.rawValue)
        audio_sources: \(sources)
        ---

        # \(result.summary.title)

        ## Summary

        \(Self.list(result.summary.keyPoints, empty: "No key points identified."))

        ## Decisions

        \(Self.list(result.summary.decisions, empty: "No decisions identified."))

        ## Action Items

        \(Self.list(result.summary.actionItems, empty: "No action items identified."))

        ## Follow-ups and Questions

        \(Self.list(result.summary.followUps, empty: "No follow-ups identified."))

        ## Transcript

        \(result.transcript.plainText)
        """

        return MarkdownDocument(filename: filename, contents: contents)
    }

    private func sanitizedTitle(_ title: String) -> String {
        let fallback = "meeting"
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let scalars = title.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let sanitized = String(scalars)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
        return sanitized.isEmpty ? fallback : sanitized
    }

    private static func list(_ values: [String], empty: String) -> String {
        guard !values.isEmpty else {
            return "- \(empty)"
        }
        return values.map { "- \($0)" }.joined(separator: "\n")
    }

    private static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        return formatter
    }()

    private static let metadataDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}

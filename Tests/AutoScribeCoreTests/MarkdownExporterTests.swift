import AutoScribeCore
import XCTest

final class MarkdownExporterTests: XCTestCase {
    func testRenderIncludesMetadataSummaryAndTranscript() {
        let session = RecordingSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_000_600),
            audioSources: [.microphone, .systemAudio],
            processingMode: .api,
            outputDirectory: URL(fileURLWithPath: "/tmp/autoscribe"),
            temporaryDirectory: URL(fileURLWithPath: "/tmp/autoscribe-temp")
        )

        let result = ProcessingResult(
            transcript: Transcript(segments: [
                TranscriptSegment(speaker: "Microphone", startTime: 0, text: "Hello"),
                TranscriptSegment(speaker: "System Audio", startTime: 2, text: "Hi there")
            ]),
            summary: MeetingSummary(
                title: "Weekly Sync",
                keyPoints: ["Discussed launch plan"],
                decisions: ["Ship the MVP first"],
                actionItems: ["Draft release checklist"],
                followUps: ["Confirm API costs"]
            )
        )

        let document = MarkdownExporter().render(result: result, session: session)

        XCTAssertTrue(document.filename.hasSuffix("_weekly-sync.md"))
        XCTAssertTrue(document.contents.contains("processing_mode: API"))
        XCTAssertTrue(document.contents.contains("audio_sources: Microphone, System Audio"))
        XCTAssertTrue(document.contents.contains("- Discussed launch plan"))
        XCTAssertTrue(document.contents.contains("[00:00] Microphone: Hello"))
    }
}

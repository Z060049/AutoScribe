import AutoScribeCore
import XCTest

final class SettingsStoreTests: XCTestCase {
    func testSaveAndLoadSettings() {
        let suiteName = "AutoScribeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        let expected = AppSettings(
            processingMode: .api,
            outputDirectory: URL(fileURLWithPath: "/tmp/autoscribe-output", isDirectory: true),
            inactivityTimeoutSeconds: 120,
            summaryDepth: .detailed,
            shouldShowConsentReminder: false,
            hasAcceptedConsentChecklist: true
        )

        store.save(expected)

        XCTAssertEqual(store.load(), expected)
    }
}

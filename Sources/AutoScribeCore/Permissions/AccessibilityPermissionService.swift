import ApplicationServices
import Foundation

public enum AccessibilityPermissionService {
    public static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    public static func requestPrompt() -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public static var settingsURL: URL {
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
    }
}

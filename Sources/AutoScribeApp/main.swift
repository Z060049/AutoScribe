import AppKit
import AutoScribeCore
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = AutoScribeController()
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()
    private var commandKeyMonitor: Any?
    private var localCommandKeyMonitor: Any?
    private var lastCommandTap: Date?
    private var isCommandPressed = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMainMenu()
        configureStatusItem()
        configurePopover()
        configureGlobalShortcut()
        bindState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let commandKeyMonitor {
            NSEvent.removeMonitor(commandKeyMonitor)
        }
        if let localCommandKeyMonitor {
            NSEvent.removeMonitor(localCommandKeyMonitor)
        }
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.imagePosition = .imageLeading
        self.statusItem = statusItem
        updateStatusItem(for: controller.state)
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Quit AutoScribe",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func configurePopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 460, height: 680)
        popover.contentViewController = NSHostingController(rootView: MenuBarRootView(controller: controller))
        self.popover = popover
    }

    private func configureGlobalShortcut() {
        logDiagnostic("Installing double-Command shortcut monitors.")
        logAccessibilityStatus()

        commandKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        localCommandKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }

        if commandKeyMonitor == nil {
            logDiagnostic("Global shortcut monitor was not installed.", level: .warning)
        }
    }

    private func bindState() {
        controller.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.updateStatusItem(for: state)
            }
            .store(in: &cancellables)
    }

    private func updateStatusItem(for state: AppState) {
        statusItem?.button?.title = " AutoScribe: \(state.title)"
        statusItem?.button?.image = NSImage(systemSymbolName: state.menuBarSymbolName, accessibilityDescription: state.title)
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover else {
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let commandIsCurrentlyPressed = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .contains(.command)

        guard commandIsCurrentlyPressed else {
            isCommandPressed = false
            return
        }

        guard !isCommandPressed else {
            return
        }
        isCommandPressed = true

        let now = Date()
        defer { lastCommandTap = now }

        guard let lastCommandTap, now.timeIntervalSince(lastCommandTap) <= 0.45 else {
            return
        }

        Task { @MainActor in
            controller.addDiagnostic("Double Command shortcut detected.")
            controller.toggleRecording()
        }
    }

    private func logAccessibilityStatus() {
        let trusted = AccessibilityPermissionService.isTrusted
        logDiagnostic(
            trusted
                ? "Accessibility permission is trusted."
                : "Accessibility permission is not trusted. If double-Command does not work, enable it in System Settings > Privacy & Security > Accessibility.",
            level: trusted ? .info : .warning
        )
    }

    private func logDiagnostic(_ message: String, level: DiagnosticEvent.Level = .info) {
        Task { @MainActor in
            controller.addDiagnostic(message, level: level)
        }
    }
}

let appDelegate = AppDelegate()
NSApplication.shared.delegate = appDelegate
NSApplication.shared.run()

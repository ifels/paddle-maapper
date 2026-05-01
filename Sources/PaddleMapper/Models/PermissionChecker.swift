import ApplicationServices
import AppKit

/// Checks and prompts for macOS Accessibility permission required by CGEvent.
final class PermissionChecker: ObservableObject {
    /// Whether Accessibility permission is currently granted.
    @Published var isAccessibilityGranted: Bool = false

    /// Check current Accessibility permission status.
    static func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Whether the code signing certificate is installed.
    @Published var isCertInstalled: Bool = false

    /// Observer for System Settings deactivation (to bring Paddle Mapper back to front)
    private var systemSettingsObserver: NSObjectProtocol?

    /// Check and update the published state.
    func checkPermission() {
        isAccessibilityGranted = AXIsProcessTrusted()
    }

    /// Check if the PaddleMapper Developer certificate is installed.
    /// Runs the check on a background thread to avoid blocking the UI.
    func checkCertInstalled() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let installed = Self.queryCertInstalled()
            DispatchQueue.main.async {
                self?.isCertInstalled = installed
            }
        }
    }

    /// Synchronous check for certificate presence (call from background thread).
    private static func queryCertInstalled() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-identity", "-v", "-p", "codesigning",
                             NSHomeDirectory() + "/Library/Keychains/login.keychain-db"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.contains("PaddleMapper Developer")
        } catch {
            return false
        }
    }

    /// Prompt the user to grant Accessibility permission.
    /// Opens System Preferences and shows a confirmation dialog.
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        isAccessibilityGranted = trusted

        if trusted {
            LogWriter.log("[PaddleMapper] Accessibility permission granted")
        } else {
            LogWriter.log("[PaddleMapper] Accessibility permission not granted - user prompted")
        }
    }

    /// Open System Preferences directly to the Accessibility pane.
    /// For LSUIElement apps, macOS does not return to our window after System Settings closes.
    /// We observe System Settings deactivation and reactivate our window.
    func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)

        // Watch for System Settings losing focus so we can bring Paddle Mapper back
        observeSystemSettingsDeactivation()
    }

    // MARK: - System Settings Deactivation Observer

    /// Observe when System Settings is deactivated (closed or user switches away),
    /// then reactivate Paddle Mapper window so it becomes the foreground app.
    private func observeSystemSettingsDeactivation() {
        // Remove any previous observer
        if let observer = systemSettingsObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }

        systemSettingsObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == "com.apple.SystemSettings" else {
                return
            }

            // System Settings was deactivated - bring Paddle Mapper back to front
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first(where: { $0.isVisible }) {
                window.makeKeyAndOrderFront(nil)
            }

            // Clean up observer
            if let observer = self?.systemSettingsObserver {
                NSWorkspace.shared.notificationCenter.removeObserver(observer)
                self?.systemSettingsObserver = nil
            }
        }
    }

    /// Start periodic permission checking (in case user grants while app is running).
    /// Also monitors certificate installation status.
    func startMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkPermission()
            self?.checkCertInstalled()
        }
    }
}

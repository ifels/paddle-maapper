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
    func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
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

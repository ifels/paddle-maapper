import SwiftUI

/// 系统设置页面：开机启动 + 辅助功能权限状态 + 证书管理 + 关于信息
struct SystemSettingsPageView: View {
    @ObservedObject var permissionChecker: PermissionChecker
    @ObservedObject var monitor: ControllerMonitor
    @ObservedObject var launchAtLogin: LaunchAtLoginManager

    var body: some View {
        VStack(spacing: 0) {
            // ─── 页面标题 ───
            PageHeader(
                title: NSLocalizedString("SIDEBAR_SETTINGS", comment: "Settings"),
                icon: "gearshape.fill"
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // ─── 开机启动 ───
                    launchAtLoginSection

                    // ─── 辅助功能权限 ───
                    accessibilitySection

                    // ─── 证书管理 ───
                    certificateSection

                    // ─── 关于 ───
                    aboutSection
                }
                .padding(20)
            }
        }
        .onAppear {
            permissionChecker.checkCertInstalled()
            launchAtLogin.refreshStatus()
        }
    }

    // MARK: - Launch at Login Section

    private var launchAtLoginSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                icon: "power",
                iconColor: .accentColor,
                title: NSLocalizedString("SETTINGS_LAUNCH_AT_LOGIN", comment: "Launch at Login section title")
            )

            HStack(spacing: 12) {
                Toggle(isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { _ in launchAtLogin.toggle() }
                )) {
                    Text(NSLocalizedString("SETTINGS_LAUNCH_AT_LOGIN_DESC", comment: "Launch at Login toggle label"))
                        .font(.body)
                }
                .toggleStyle(.switch)
                .controlSize(.small)

                Spacer()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        }
    }

    // MARK: - Accessibility Section

    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                icon: "lock.shield.fill",
                iconColor: permissionChecker.isAccessibilityGranted ? .green : .orange,
                title: NSLocalizedString("SETTINGS_ACCESSIBILITY", comment: "Accessibility section title")
            )

            HStack(spacing: 12) {
                Circle()
                    .fill(permissionChecker.isAccessibilityGranted ? Color.green : Color.red)
                    .frame(width: 12, height: 12)

                Text(permissionChecker.isAccessibilityGranted
                     ? NSLocalizedString("SETTINGS_ACCESSIBILITY_GRANTED", comment: "Accessibility granted")
                     : NSLocalizedString("SETTINGS_ACCESSIBILITY_DENIED", comment: "Accessibility denied"))
                    .font(.body)

                Spacer()

                if !permissionChecker.isAccessibilityGranted {
                    Button(NSLocalizedString("GRANT_PERMISSION", comment: "Grant permission button")) {
                        permissionChecker.requestAccessibility()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Button(NSLocalizedString("SETTINGS_OPEN_PREF", comment: "Open preferences button")) {
                    permissionChecker.openAccessibilityPreferences()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        }
    }

    // MARK: - Certificate Section

    private var certificateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                icon: "certificate.fill",
                iconColor: permissionChecker.isCertInstalled ? .green : .secondary,
                title: NSLocalizedString("SETTINGS_CERTIFICATE", comment: "Certificate section title")
            )

            HStack(spacing: 12) {
                Image(systemName: permissionChecker.isCertInstalled ? "checkmark.seal.fill" : "xmark.seal")
                    .foregroundColor(permissionChecker.isCertInstalled ? .green : .secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(permissionChecker.isCertInstalled
                         ? NSLocalizedString("CERT_INSTALLED", comment: "Certificate installed")
                         : NSLocalizedString("SETTINGS_CERT_NOT_INSTALLED", comment: "Certificate not installed"))
                        .font(.body)
                    Text(NSLocalizedString("SETTINGS_CERT_DESC", comment: "Certificate description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if permissionChecker.isCertInstalled {
                    Button(NSLocalizedString("REMOVE_CERTIFICATE", comment: "Remove certificate button")) {
                        runCertScript(withArgs: "--remove")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                } else {
                    Button(NSLocalizedString("INSTALL_CERTIFICATE", comment: "Install certificate button")) {
                        runCertScript(withArgs: nil)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                icon: "info.circle.fill",
                iconColor: .blue,
                title: NSLocalizedString("SETTINGS_ABOUT", comment: "About section title")
            )

            HStack(spacing: 12) {
                Image(systemName: "gamecontroller.fill")
                    .font(.title)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Paddle Mapper")
                        .font(.headline)
                    Text("v\(appVersion)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func sectionHeader(icon: String, iconColor: Color, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.title3)
            Text(title)
                .font(.headline)
        }
    }

    // MARK: - Certificate Script

    private func runCertScript(withArgs args: String?) {
        let argSuffix = args.map { " \($0)" } ?? ""
        let scriptPath = Bundle.main.bundlePath + "/Contents/Resources/setup-cert.sh"

        if FileManager.default.fileExists(atPath: scriptPath) {
            openTerminalWithCommand(command: "\"\(scriptPath)\"\(argSuffix)")
        } else {
            let devScriptPath = (Bundle.main.bundlePath as NSString)
                .deletingLastPathComponent + "/setup-cert.sh"

            if FileManager.default.fileExists(atPath: devScriptPath) {
                openTerminalWithCommand(command: "\"\(devScriptPath)\"\(argSuffix)")
            } else {
                let homePath = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
                let homeScript = homePath + "/.paddlemapper-cert/setup-cert.sh"

                if FileManager.default.fileExists(atPath: homeScript) {
                    openTerminalWithCommand(command: "\"\(homeScript)\"\(argSuffix)")
                } else {
                    let projectPath = findProjectPath()
                    openTerminalWithCommand(
                        command: "cd \"\(projectPath)\" && chmod +x setup-cert.sh && ./setup-cert.sh\(argSuffix)"
                    )
                }
            }
        }
    }

    private func findProjectPath() -> String {
        let execPath = Bundle.main.executablePath ?? ""
        if execPath.contains("/.build/") {
            let components = execPath.components(separatedBy: "/.build/")
            if let root = components.first {
                return root
            }
        }
        let bundlePath = Bundle.main.bundlePath
        return (bundlePath as NSString).deletingLastPathComponent
    }

    private func openTerminalWithCommand(command: String) {
        let tempDir = NSTemporaryDirectory()
        let tempFile = tempDir + "paddlemapper-cert-command.command"
        let scriptContent = "#!/bin/bash\n\(command)\n"
        do {
            try scriptContent.write(toFile: tempFile, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempFile)
            NSWorkspace.shared.open(URL(fileURLWithPath: tempFile))
        } catch {
            LogWriter.log("[PaddleMapper] Failed to create temp script: \(error)")
            NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Utilities/Terminal.app"))
        }
    }
}

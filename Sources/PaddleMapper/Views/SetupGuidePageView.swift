import SwiftUI

/// 操作手册页面：内联展示权限引导和证书安装指南（不再是 Sheet）
struct SetupGuidePageView: View {
    @ObservedObject var permissionChecker: PermissionChecker

    var body: some View {
        VStack(spacing: 0) {
            // ─── 页面标题 ───
            PageHeader(
                title: NSLocalizedString("SIDEBAR_SETUP_GUIDE", comment: "Setup Guide"),
                icon: "book.fill"
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // ─── 1. 为什么需要辅助功能权限 ───
                    guideSection(
                        icon: "lock.shield.fill",
                        iconColor: .orange,
                        title: NSLocalizedString("SECTION1_TITLE", comment: "Section 1 title"),
                        content: NSLocalizedString("SECTION1_CONTENT", comment: "Section 1 content")
                    )

                    // ─── 2. 如何授权辅助功能权限 ───
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                            Text(NSLocalizedString("SECTION2_TITLE", comment: "Section 2 title"))
                                .font(.headline)
                        }
                        Text(NSLocalizedString("SECTION2_SUBTITLE", comment: "Section 2 subtitle"))
                            .font(.body)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 8) {
                                Text("①")
                                    .font(.body.bold())
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(NSLocalizedString("SECTION2_STEP1_TEXT", comment: "Step 1 instruction"))
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                    Button(action: {
                                        permissionChecker.openAccessibilityPreferences()
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "gear")
                                            Text(NSLocalizedString("SECTION2_STEP1_BUTTON", comment: "Open System Settings button"))
                                        }
                                        .font(.subheadline.bold())
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.regular)
                                }
                            }

                            HStack(alignment: .top, spacing: 8) {
                                Text("②")
                                    .font(.body.bold())
                                    .foregroundColor(.blue)
                                Text(NSLocalizedString("SECTION2_STEP2", comment: "Step 2 instruction"))
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }

                            HStack(alignment: .top, spacing: 8) {
                                Text("③")
                                    .font(.body.bold())
                                    .foregroundColor(.blue)
                                Text(NSLocalizedString("SECTION2_STEP3", comment: "Step 3 instruction"))
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }

                            HStack(alignment: .top, spacing: 8) {
                                Text("④")
                                    .font(.body.bold())
                                    .foregroundColor(.blue)
                                Text(NSLocalizedString("SECTION2_STEP4", comment: "Step 4 instruction"))
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.leading, 8)
                    }

                    // ─── 版本更新说明 ───
                    guideSection(
                        icon: "arrow.triangle.2.circlepath",
                        iconColor: .purple,
                        title: NSLocalizedString("SECTION_UPDATE_TITLE", comment: "Update warning title"),
                        content: NSLocalizedString("SECTION_UPDATE_CONTENT", comment: "Update warning content")
                    )

                    Divider()
                        .padding(.vertical, 4)

                    // ─── 3. 安装签名证书（推荐） ───
                    guideSection(
                        icon: "certificate.fill",
                        iconColor: .green,
                        title: NSLocalizedString("SECTION3_TITLE", comment: "Section 3 title"),
                        content: NSLocalizedString("SECTION3_CONTENT", comment: "Section 3 content")
                    )

                    guideSubSection(
                        title: NSLocalizedString("SECTION3_1_TITLE", comment: "Section 3.1 title"),
                        content: NSLocalizedString("SECTION3_1_CONTENT", comment: "Section 3.1 content")
                    )

                    guideSubSection(
                        title: NSLocalizedString("SECTION3_2_TITLE", comment: "Section 3.2 title"),
                        content: NSLocalizedString("SECTION3_2_CONTENT", comment: "Section 3.2 content")
                    )

                    // ─── 3.3 安装证书按钮 / 已安装状态 ───
                    HStack {
                        Spacer()
                        if permissionChecker.isCertInstalled {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(NSLocalizedString("CERT_INSTALLED", comment: "Certificate installed status"))
                                    .foregroundColor(.secondary)
                            }
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.1)))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.3), lineWidth: 1))
                        } else {
                            Button(action: installCertificate) {
                                HStack(spacing: 8) {
                                    Image(systemName: "terminal.fill")
                                    Text(NSLocalizedString("INSTALL_CERTIFICATE", comment: "Install certificate button"))
                                }
                                .font(.headline)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                        Spacer()
                    }
                    .padding(.top, 8)

                    Divider()
                        .padding(.vertical, 4)

                    // ─── 4. 如何删除证书 ───
                    guideSection(
                        icon: "trash.circle.fill",
                        iconColor: .red,
                        title: NSLocalizedString("SECTION4_TITLE", comment: "Section 4 title"),
                        content: NSLocalizedString("SECTION4_CONTENT", comment: "Section 4 content")
                    )

                    guideSubSection(
                        title: NSLocalizedString("SECTION4_1_TITLE", comment: "Section 4.1 title"),
                        content: NSLocalizedString("SECTION4_1_CONTENT", comment: "Section 4.1 content")
                    )

                    // ─── 4.2 删除证书按钮 ───
                    HStack {
                        Spacer()
                        if permissionChecker.isCertInstalled {
                            Button(action: removeCertificate) {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash")
                                    Text(NSLocalizedString("REMOVE_CERTIFICATE", comment: "Remove certificate button"))
                                }
                                .font(.headline)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .foregroundColor(.red)
                        }
                        Spacer()
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
        }
        .onAppear {
            permissionChecker.checkCertInstalled()
        }
    }

    // MARK: - Helper Views

    private func guideSection(
        icon: String,
        iconColor: Color,
        title: String,
        content: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.title3)
                Text(title)
                    .font(.headline)
            }
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func guideSubSection(
        title: String,
        content: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.bold())
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 28)
    }

    // MARK: - Actions

    private func installCertificate() {
        runCertScript(withArgs: nil)
    }

    private func removeCertificate() {
        runCertScript(withArgs: "--remove")
    }

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

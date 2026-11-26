import SwiftUI
import AppKit

/// 操作引导的共享内容，供两个入口复用：
/// - `PermissionGuideView`：主界面弹出的 Sheet
/// - `SetupGuidePageView`：左侧「操作手册」页面
///
/// ## 章节顺序（重要）
/// 刻意按「先装证书 → 重新编译 → 再授权」排列：
///
/// 未安装签名证书时，App 是 **ad-hoc 签名**，TCC（辅助功能权限）把授权
/// 绑定在二进制的 cdhash 上。每次重新编译 cdhash 都会变，系统视为「新应用」，
/// 已授予的权限随即失效——表现就是「系统设置里明明是勾上的，App 却说没权限」。
/// 装上稳定证书后，签名身份变成 `bundle id + 证书`，重编也不变，权限才会长期保留。
struct SetupGuideContent: View {
    @ObservedObject var permissionChecker: PermissionChecker

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            orderTip

            // ─── 1. 为什么需要辅助功能权限 ───
            Group {
                guideSection(
                    icon: "lock.shield.fill",
                    iconColor: .orange,
                    title: NSLocalizedString("SECTION1_TITLE", comment: "Section 1 title"),
                    content: NSLocalizedString("SECTION1_CONTENT", comment: "Section 1 content")
                )

                // ─── 版本更新说明（解释权限为什么会丢） ───
                guideSection(
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: .purple,
                    title: NSLocalizedString("SECTION_UPDATE_TITLE", comment: "Update warning title"),
                    content: NSLocalizedString("SECTION_UPDATE_CONTENT", comment: "Update warning content")
                )
            }

            Divider()
                .padding(.vertical, 4)

            // ─── 2. 安装签名证书（先做这一步） ───
            Group {
                guideSection(
                    icon: "certificate.fill",
                    iconColor: .green,
                    title: NSLocalizedString("SECTION3_TITLE", comment: "Section 2 title: signing certificate"),
                    content: NSLocalizedString("SECTION3_CONTENT", comment: "Section 2 content")
                )

                guideSubSection(
                    title: NSLocalizedString("SECTION3_1_TITLE", comment: "Section 2.1 title"),
                    content: NSLocalizedString("SECTION3_1_CONTENT", comment: "Section 2.1 content")
                )

                guideSubSection(
                    title: NSLocalizedString("SECTION3_2_TITLE", comment: "Section 2.2 title"),
                    content: NSLocalizedString("SECTION3_2_CONTENT", comment: "Section 2.2 content")
                )

                certificateActionRow
            }

            Divider()
                .padding(.vertical, 4)

            // ─── 3. 授权辅助功能权限 ───
            permissionStepsSection

            Divider()
                .padding(.vertical, 4)

            // ─── 4. 如何删除证书 ───
            Group {
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

                removalActionRow
            }
        }
    }

    // MARK: - 顺序提示

    /// 顶部高亮提示：把「先证书、后授权」这个顺序直接写在界面上，
    /// 避免用户先授权、重编后又丢权限、再反复授权。
    private var orderTip: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
                .font(.body)
            Text(NSLocalizedString("GUIDE_ORDER_TIP", comment: "Recommended setup order"))
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.25), lineWidth: 1))
    }

    // MARK: - 权限授权步骤

    private var permissionStepsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                Text(NSLocalizedString("SECTION2_TITLE", comment: "Section 3 title: accessibility permission"))
                    .font(.headline)
            }
            Text(NSLocalizedString("SECTION2_SUBTITLE", comment: "Section 3 subtitle"))
                .font(.body)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                // 步骤①：带「打开系统设置」按钮
                HStack(alignment: .top, spacing: 8) {
                    Text("①")
                        .font(.body.bold())
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("SECTION2_STEP1_TEXT", comment: "Step 1 instruction"))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
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

                stepRow(marker: "②", key: "SECTION2_STEP2", comment: "Step 2 instruction")
                stepRow(marker: "③", key: "SECTION2_STEP3", comment: "Step 3 instruction")
                stepRow(marker: "④", key: "SECTION2_STEP4", comment: "Step 4 instruction")
            }
            .padding(.leading, 8)
        }
    }

    private func stepRow(marker: String, key: String, comment: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(marker)
                .font(.body.bold())
                .foregroundColor(.blue)
            Text(NSLocalizedString(key, comment: comment))
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 证书按钮行

    private var certificateActionRow: some View {
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
    }

    private var removalActionRow: some View {
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

    // MARK: - 通用区块

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

    private func guideSubSection(title: String, content: String) -> some View {
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

    // MARK: - 证书脚本操作

    private func installCertificate() {
        runCertScript(withArgs: nil)
    }

    private func removeCertificate() {
        runCertScript(withArgs: "--remove")
    }

    /// 运行 setup-cert.sh 脚本（安装或删除）
    private func runCertScript(withArgs args: String?) {
        let argSuffix = args.map { " \($0)" } ?? ""
        let scriptPath = Bundle.main.bundlePath + "/Contents/Resources/setup-cert.sh"

        // 依次尝试候选位置，找到第一个存在的脚本
        let homePath = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let candidates = [scriptPath] + devScriptCandidates() + ["\(homePath)/.paddlemapper-cert/setup-cert.sh"]

        guard let resolved = candidates.first(where: {
            FileManager.default.isExecutableFile(atPath: $0) || FileManager.default.fileExists(atPath: $0)
        }) else {
            // 找不到脚本时给出明确提示，而不是在终端里跑一条必然失败的命令
            LogWriter.log("[PaddleMapper] setup-cert.sh not found in: \(candidates)")
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = NSLocalizedString("CERT_SCRIPT_MISSING_TITLE", comment: "Missing cert script title")
            alert.informativeText = String(
                format: NSLocalizedString("CERT_SCRIPT_MISSING_INFO", comment: "Missing cert script detail"),
                scriptPath
            )
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        openTerminalWithCommand(command: "\"\(resolved)\"\(argSuffix)")
    }

    /// 开发模式下的候选路径：项目根目录（build/PaddleMapper.app 的上两级）
    /// 以及 App 同级的上一层目录（build_app.sh 直接产出的布局）。
    private func devScriptCandidates() -> [String] {
        let bundlePath = Bundle.main.bundlePath
        var dirs: [String] = []
        var cursor = (bundlePath as NSString).deletingLastPathComponent

        // 向上最多找 3 层，覆盖 build/PaddleMapper.app 与自定义输出目录
        for _ in 0..<3 {
            dirs.append(cursor + "/setup-cert.sh")
            let parent = (cursor as NSString).deletingLastPathComponent
            if parent == cursor { break }
            cursor = parent
        }
        return dirs
    }

    /// 在终端中执行指定命令
    private func openTerminalWithCommand(command: String) {
        // 生成临时 .command 文件，让 Terminal.app 自动执行
        // 比 AppleScript do script 更可靠，避免引号/注释等转义问题
        let tempFile = NSTemporaryDirectory() + "paddlemapper-cert-command.command"
        let scriptContent = "#!/bin/bash\n\(command)\n"
        do {
            try scriptContent.write(toFile: tempFile, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempFile)
            NSWorkspace.shared.open(URL(fileURLWithPath: tempFile))
        } catch {
            LogWriter.log("[PaddleMapper] Failed to create temp script: \(error)")
            // 回退方案：直接打开 Terminal
            NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Utilities/Terminal.app"))
        }
    }
}

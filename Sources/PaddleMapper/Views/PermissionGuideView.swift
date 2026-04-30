import SwiftUI

/// 操作引导页面：辅助功能权限说明 + 证书安装引导
/// 作为 Sheet 弹出展示
struct PermissionGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var permissionChecker: PermissionChecker

    var body: some View {
        VStack(spacing: 0) {
            // ─── 标题栏 ───
            HStack {
                Image(systemName: "book.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("操作引导")
                    .font(.title2.bold())
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // ─── 1. 为什么需要辅助功能权限 ───
                    guideSection(
                        icon: "lock.shield.fill",
                        iconColor: .orange,
                        title: "1. 为什么需要「辅助功能」权限？",
                        content: """
                        PaddleMapper 的核心功能是将手柄拨片按键映射为键盘按键（如 F15-F18）。\
                        要模拟键盘输入，macOS 要求应用必须拥有「辅助功能」权限，否则系统会拦截所有按键模拟请求。

                        没有此权限，PaddleMapper 将无法工作。
                        """
                    )

                    // ─── 2. 如何授权辅助功能权限 ───
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                            Text("2. 如何授权「辅助功能」权限？")
                                .font(.headline)
                        }
                        Text("按以下步骤操作：")
                            .font(.body)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 10) {
                            // 步骤①：带「打开系统设置」按钮
                            HStack(alignment: .top, spacing: 8) {
                                Text("①")
                                    .font(.body.bold())
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("点击下方按钮，系统将自动跳转到「隐私与安全性 → 辅助功能」页面：")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                    Button(action: {
                                        permissionChecker.openAccessibilityPreferences()
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "gear")
                                            Text("打开系统设置")
                                        }
                                        .font(.subheadline.bold())
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.regular)
                                }
                            }

                            // 步骤②
                            HStack(alignment: .top, spacing: 8) {
                                Text("②")
                                    .font(.body.bold())
                                    .foregroundColor(.blue)
                                Text("在列表中找到 PaddleMapper，勾选其左侧的开关使其变为蓝色（已开启）。")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }

                            // 步骤③
                            HStack(alignment: .top, spacing: 8) {
                                Text("③")
                                    .font(.body.bold())
                                    .foregroundColor(.blue)
                                Text("如果列表中没有 PaddleMapper，请先点击主界面的「Grant Permission」按钮，应用会弹出授权请求对话框，点击「打开系统设置」后再按步骤 ② 操作。")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }

                            // 步骤④
                            HStack(alignment: .top, spacing: 8) {
                                Text("④")
                                    .font(.body.bold())
                                    .foregroundColor(.blue)
                                Text("授权完成后，PaddleMapper 会自动检测到权限变化并刷新状态。")
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
                        title: "⚠️ 版本更新后权限可能丢失",
                        content: """
                        如果您没有安装签名证书，每次编译新版本后 macOS 会将其视为「新应用」，\
                        之前授予的辅助功能权限会自动失效，需要重新授权。

                        解决方案：安装签名证书（见下方），让每次编译都使用同一身份签名，\
                        系统将认为它是同一应用，权限不会丢失。
                        """
                    )

                    Divider()
                        .padding(.vertical, 4)

                    // ─── 3. 安装签名证书（推荐） ───
                    guideSection(
                        icon: "certificate.fill",
                        iconColor: .green,
                        title: "3. 安装签名证书（推荐）",
                        content: """
                        强烈建议安装签名证书，可以一劳永逸地解决版本更新后权限丢失的问题。
                        """
                    )

                    // ─── 3.1 安装证书有什么好处 ───
                    guideSubSection(
                        title: "3.1 安装证书有什么好处？",
                        content: """
                        每次更新应用时，应用的身份标识会发生变化，系统会认为是「新应用」而重置权限。

                        安装证书后，所有版本都使用同一身份签名，系统识别为同一应用：\
                        ✅ 辅助功能权限一次授权，永久有效\
                        ✅ 无需每次更新后重新授权\
                        ✅ 证书有效期 10 年，长期稳定
                        """
                    )

                    // ─── 3.2 如何安装 ───
                    guideSubSection(
                        title: "3.2 如何安装？",
                        content: """
                        安装过程大约 1 分钟，请按以下步骤操作：

                        ① 点击下方「安装证书」按钮，系统终端将自动打开并执行安装脚本。

                        ② 脚本执行过程中可能需要输入两次密码：\
                        ‣ 第一次：Mac 登录密码（用于解锁钥匙串）\
                        ‣ 第二次：Mac 管理员密码（用于将证书设为信任）

                        ③ 安装完成后，终端会显示「✅ Certificate installed successfully!」。

                        ④ 此后每次更新应用时，将自动使用该证书签名，权限不再丢失。

                        如需移除证书，可在终端执行：./setup-cert.sh --remove
                        """
                    )

                    // ─── 3.3 安装证书按钮 / 已安装状态 ───
                    HStack {
                        Spacer()
                        if permissionChecker.isCertInstalled {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("已安装证书")
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
                                    Text("安装证书")
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
                .padding(20)
            }
        }
        .frame(width: 560, height: 640)
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

    /// 打开终端执行证书安装脚本
    private func installCertificate() {
        let scriptPath = Bundle.main.bundlePath + "/Contents/Resources/setup-cert.sh"

        // 检查脚本是否在 app bundle 内
        if FileManager.default.fileExists(atPath: scriptPath) {
            openTerminalWithCommand(command: "\"\(scriptPath)\"")
        } else {
            // 回退到项目目录下的脚本（开发模式）
            let devScriptPath = (Bundle.main.bundlePath as NSString)
                .deletingLastPathComponent + "/setup-cert.sh"

            if FileManager.default.fileExists(atPath: devScriptPath) {
                openTerminalWithCommand(command: "\"\(devScriptPath)\"")
            } else {
                // 脚本不存在，尝试用 source code 目录下的脚本
                let homePath = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
                let homeScript = homePath + "/.paddlemapper-cert/setup-cert.sh"

                if FileManager.default.fileExists(atPath: homeScript) {
                    openTerminalWithCommand(command: "\"\(homeScript)\"")
                } else {
                    // 最终回退：在终端中 cd 到项目目录并执行
                    let projectPath = findProjectPath()
                    openTerminalWithCommand(
                        command: "cd \"\(projectPath)\" && chmod +x setup-cert.sh && ./setup-cert.sh"
                    )
                }
            }
        }
    }

    /// 尝试找到项目目录
    private func findProjectPath() -> String {
        // 尝试从可执行文件路径推断项目目录
        let execPath = Bundle.main.executablePath ?? ""
        if execPath.contains("/.build/") {
            // SPM 开发模式：.build/debug/PaddleMapper → 项目根目录
            let components = execPath.components(separatedBy: "/.build/")
            if let root = components.first {
                return root
            }
        }
        // 回退到 build 目录的上级
        let bundlePath = Bundle.main.bundlePath
        return (bundlePath as NSString).deletingLastPathComponent
    }

    /// 在终端中执行指定命令
    private func openTerminalWithCommand(command: String) {
        // 使用 AppleScript 在 Terminal.app 中执行命令
        let appleScript = """
        tell application "Terminal"
            activate
            do script "\(command.replacingOccurrences(of: "\\", with: "\\\\"))"
        end tell
        """

        if let script = NSAppleScript(source: appleScript) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if let error = error {
                LogWriter.log("[PaddleMapper] Failed to open Terminal: \(error)")
                // 回退方案：直接打开 Terminal
                NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Utilities/Terminal.app"))
            }
        }
    }
}

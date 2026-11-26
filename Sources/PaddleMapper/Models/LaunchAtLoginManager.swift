import Foundation
import AppKit

/// 管理开机启动 (Login Item)。
///
/// macOS 12 (Monterey) 没有 `SMAppService` (macOS 13+), 因此改用
/// `~/Library/LaunchAgents/<bundle-id>.plist` 的方式实现:
///
/// - 开启: 写入 LaunchAgent plist (`RunAtLoad = true`), 登录时由 launchd 自动拉起
/// - 关闭: 卸载 (bootout) 并删除 plist
/// - 状态: 以 plist 是否存在为准
///
/// 由 LaunchAgent 拉起时会带 `--login-item` 参数, App 据此判断「登录启动」,
/// 只驻留菜单栏而不弹出主窗口。
final class LaunchAtLoginManager: ObservableObject {
    /// 登录项启动时附加的命令行参数
    static let loginLaunchArgument = "--login-item"

    /// 当前是否已开启开机启动
    @Published var isEnabled: Bool = false

    private static let label = "com.ifels.controlflex.paddlemapper"

    private var agentPlistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(Self.label).plist")
    }

    init() {
        refreshStatus()
    }

    /// 刷新当前状态
    func refreshStatus() {
        isEnabled = FileManager.default.fileExists(atPath: agentPlistURL.path)
    }

    /// 切换开机启动状态
    func toggle() {
        if isEnabled {
            disable()
        } else {
            enable()
        }
        refreshStatus()
    }

    // MARK: - Enable / Disable

    private func enable() {
        guard let executableURL = Bundle.main.executableURL else {
            LogWriter.log("[PaddleMapper] LaunchAtLogin: executableURL unavailable")
            return
        }

        let launchAgent: [String: Any] = [
            "Label": Self.label,
            "ProgramArguments": [executableURL.path, Self.loginLaunchArgument],
            "RunAtLoad": true,
            "KeepAlive": false,
            "LimitLoadToSessionType": "Aqua",
            "ProcessType": "Interactive",
        ]

        do {
            try FileManager.default.createDirectory(
                at: agentPlistURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try PropertyListSerialization.data(
                fromPropertyList: launchAgent,
                format: .xml,
                options: 0
            )
            try data.write(to: agentPlistURL)
            LogWriter.log("[PaddleMapper] LaunchAtLogin enabled: \(agentPlistURL.path)")
        } catch {
            LogWriter.log("[PaddleMapper] Failed to enable launch at login: \(error)")
        }
    }

    private func disable() {
        // 若已被 launchd 加载, 先卸载; 未加载时 bootout 会失败, 忽略即可
        runLaunchctl(["bootout", "gui/\(getuid())/\(Self.label)"])

        do {
            if FileManager.default.fileExists(atPath: agentPlistURL.path) {
                try FileManager.default.removeItem(at: agentPlistURL)
            }
            LogWriter.log("[PaddleMapper] LaunchAtLogin disabled")
        } catch {
            LogWriter.log("[PaddleMapper] Failed to disable launch at login: \(error)")
        }
    }

    // MARK: - Helpers

    private func runLaunchctl(_ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            LogWriter.log("[PaddleMapper] launchctl \(arguments.joined(separator: " ")) failed: \(error)")
        }
    }
}

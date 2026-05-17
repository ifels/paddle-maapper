import SwiftUI
import ServiceManagement

/// SwiftUI App declaration (no @main - main entry is in main.swift)
///
/// 方案 B: 菜单栏 App (LSUIElement = true), Dock 图标按窗口可见性动态切换
/// - 默认 .accessory: 仅菜单栏图标, 不在 Dock / Cmd+Tab 出现
/// - 主窗口可见时切到 .regular: Dock 显示图标, 关闭窗口后回到 .accessory
/// - MenuBarExtra 始终常驻, 是窗口关闭后唯一交互入口
struct PaddleMapperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var monitor = ControllerMonitor()
    @StateObject private var config = MappingConfig()
    @StateObject private var permissionChecker = PermissionChecker()
    @StateObject private var launchAtLogin = LaunchAtLoginManager()

    var body: some Scene {
        // 单例 Window Scene：多次 openWindow(id:"main") 不会创建多个实例
        Window("Paddle Mapper", id: "main") {
            ContentView(
                monitor: monitor,
                config: config,
                permissionChecker: permissionChecker,
                launchAtLogin: launchAtLogin
            )
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 600)
        .commands {
            // Remove "New Window" from File menu (LSUIElement=true 时菜单不可见，但保留以防万一)
            CommandGroup(replacing: .newItem) { }
        }

        // 状态栏唯一交互入口：左键弹出菜单
        MenuBarExtra("Paddle Mapper", systemImage: menuBarIcon) {
            MenuBarContent(
                monitor: monitor,
                config: config
            )
        }
    }

    // MARK: - Menu Bar

    private var menuBarIcon: String {
        monitor.isControllerConnected
            ? (monitor.supportsPaddles ? "gamecontroller.fill" : "gamecontroller")
            : "gamecontroller"
    }
}

// MARK: - Menu Bar Content View

/// 菜单栏下拉菜单内容
/// 纯菜单栏 App 的唯一交互入口
struct MenuBarContent: View {
    @ObservedObject var monitor: ControllerMonitor
    @ObservedObject var config: MappingConfig
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            if monitor.isControllerConnected {
                Text(monitor.controllerName)
                    .font(.caption)

                Toggle("Mapping Enabled", isOn: $monitor.mappingEnabled)

                Divider()

                ForEach(ControllerMonitor.Paddle.allCases) { paddle in
                    let fKey = config.mapping(for: paddle) ?? "None"
                    Text("\(paddle.shortName) → \(fKey)")
                }
            } else {
                Text("No Controller Connected")
            }

            Divider()

            Button("Open Paddle Mapper") {
                openMainWindow()
            }

            Divider()

            Button("Quit Paddle Mapper") {
                NSApp.terminate(nil)
            }
        }
    }

    /// 打开主窗口并激活应用（LSUIElement App 需要显式激活才能获得键盘焦点）
    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // Window 单例 Scene：如窗口已存在则直接激活，否则创建新窗口
        openWindow(id: "main")
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Detect login launch via NSApplication notification userInfo key.
        // NSApplication.launchIsLoginItemUserInfoKey (macOS 13+) is set to true when
        // the app is launched as a Login Item (including SMAppService).
        let launchIsLoginItemKey = "NSApplicationLaunchIsLoginItem"
        let isLoginLaunch = notification.userInfo?[launchIsLoginItemKey] as? Bool ?? false

        // 监听窗口显示/关闭, 按需在 .accessory / .regular 之间切换 Dock 图标
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowVisibilityDidChange),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowVisibilityDidChange),
            name: NSWindow.willCloseNotification,
            object: nil
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if isLoginLaunch {
                // Login Item launch: close all windows, stay in menu bar only
                for window in NSApp.windows.filter({ $0.isVisible }) {
                    window.orderOut(nil)
                }
            } else {
                // User launch: bring window to foreground
                if let window = NSApp.windows.first(where: { $0.isVisible }) {
                    NSApp.activate(ignoringOtherApps: true)
                    window.makeKeyAndOrderFront(nil)
                }
            }
            // 启动后做一次同步: 用户启动 → .regular; 登录项启动 → 维持 .accessory
            self.updateActivationPolicy()
        }
    }

    @objc private func windowVisibilityDidChange(_ notification: Notification) {
        // willClose 时窗口仍然 isVisible == true, 必须延后到下一个 runloop tick 再判断
        DispatchQueue.main.async { [weak self] in
            self?.updateActivationPolicy()
        }
    }

    /// 主窗口可见 → .regular (显示 Dock 图标); 否则 .accessory (隐藏 Dock 图标)。
    /// 通过 styleMask.titled 过滤 MenuBarExtra 弹出面板等无标题栏窗口。
    private func updateActivationPolicy() {
        let hasVisibleMainWindow = NSApp.windows.contains { window in
            window.isVisible && window.styleMask.contains(.titled)
        }
        let target: NSApplication.ActivationPolicy = hasVisibleMainWindow ? .regular : .accessory
        guard NSApp.activationPolicy() != target else { return }
        NSApp.setActivationPolicy(target)
        if target == .regular {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false  // 关闭窗口后继续驻留菜单栏
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applicationOpenURL(_ app: NSApplication, url: URL) {
        // Handle reopening from login item or URL scheme
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // 无可见窗口时，通过 NotificationCenter 请求打开主窗口
            NotificationCenter.default.post(name: .openMainWindow, object: nil)
        }
        return true
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// 请求打开主窗口的通知（用于 handleReopen 场景）
    static let openMainWindow = Notification.Name("com.ifels.controlflex.paddlemapper.openMainWindow")
}

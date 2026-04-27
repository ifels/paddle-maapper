import SwiftUI

/// SwiftUI App declaration (no @main - main entry is in main.swift)
///
/// 方案 B：纯菜单栏 App (LSUIElement = true)
/// - 无 Dock 图标，无应用菜单栏
/// - MenuBarExtra 为唯一交互入口
/// - Window 单例 Scene，启动时不自动开窗
struct PaddleMapperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var monitor = ControllerMonitor()
    @StateObject private var config = MappingConfig()
    @StateObject private var permissionChecker = PermissionChecker()

    var body: some Scene {
        // 单例 Window Scene：多次 openWindow(id:"main") 不会创建多个实例
        Window("PaddleMapper", id: "main") {
            ContentView(
                monitor: monitor,
                config: config,
                permissionChecker: permissionChecker
            )
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 840, height: 520)
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
        // LSUIElement = true: 启动时不自动显示窗口，仅驻留菜单栏
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
        // Dock 图标点击或 Spotlight 重新打开时，激活菜单栏图标
        // (LSUIElement=true 下不会走此路径，但保留兼容性)
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

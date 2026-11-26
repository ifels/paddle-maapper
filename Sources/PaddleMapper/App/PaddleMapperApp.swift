import SwiftUI
import AppKit
import Combine

/// PaddleMapper 应用外壳 (macOS 12+ 兼容)
///
/// macOS 13 (Ventura) 才提供 `MenuBarExtra`、`Window` scene、`openWindow`、
/// `.windowResizability`、`.defaultSize`、`SMAppService` 等 API。
/// 为了让 App 能在 macOS 12 (Monterey) 上运行, 这里改用纯 AppKit 生命周期:
///
/// - 状态栏入口: `NSStatusItem` + `NSMenu` (替代 `MenuBarExtra`)
/// - 主窗口: `NSWindow` + `NSHostingController` 手动管理 (替代 `Window` scene + `openWindow`)
/// - 开机启动: `~/Library/LaunchAgents` 下的 LaunchAgent plist (替代 `SMAppService`)
///
/// 行为保持不变:
/// - 默认 `.accessory`: 仅菜单栏图标, 不在 Dock / Cmd+Tab 出现
/// - 主窗口可见时切到 `.regular`: Dock 显示图标, 关闭窗口后回到 `.accessory`
/// - 状态栏图标始终常驻, 是窗口关闭后唯一交互入口
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    // MARK: - Shared Models

    /// 这些 ObservableObject 由 AppDelegate 持有, 生命周期与 App 一致,
    /// 因此窗口关闭后再打开, 状态仍然保留 (等价于原先 SwiftUI App 中的 @StateObject)。
    let monitor = ControllerMonitor()
    let config = MappingConfig()
    let permissionChecker = PermissionChecker()
    let launchAtLogin = LaunchAtLoginManager()

    // MARK: - Private State

    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        buildMainMenu()
        setupStatusItem()
        observeControllerState()

        // 登录项启动: 只驻留菜单栏, 不弹主窗口
        let isLoginLaunch = CommandLine.arguments.contains(LaunchAtLoginManager.loginLaunchArgument)

        if !isLoginLaunch {
            // 用户主动启动: 显示主窗口
            showMainWindow()
        }
    }

    // MARK: - Status Item (菜单栏入口)

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu

        statusItem = item
        refreshStatusIcon()
    }

    /// 根据手柄连接状态切换菜单栏图标
    private func refreshStatusIcon() {
        let symbolName: String
        if monitor.isControllerConnected {
            symbolName = monitor.supportsPaddles ? "gamecontroller.fill" : "gamecontroller"
        } else {
            symbolName = "gamecontroller"
        }

        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Paddle Mapper")
        image?.isTemplate = true
        statusItem?.button?.image = image
        statusItem?.button?.toolTip = "Paddle Mapper"
    }

    /// 监听连接状态与扳机支持变化, 同步菜单栏图标
    private func observeControllerState() {
        monitor.$isControllerConnected
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshStatusIcon() }
            .store(in: &cancellables)

        monitor.$supportsPaddles
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshStatusIcon() }
            .store(in: &cancellables)
    }

    // MARK: - Status Menu (每次弹出时重建, 保证内容实时)

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if monitor.isControllerConnected {
            // 手柄名称 (不可点击)
            let nameItem = NSMenuItem(title: monitor.controllerName, action: nil, keyEquivalent: "")
            nameItem.isEnabled = false
            nameItem.attributedTitle = NSAttributedString(
                string: monitor.controllerName,
                attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)]
            )
            menu.addItem(nameItem)

            // 映射开关
            let toggleItem = NSMenuItem(
                title: NSLocalizedString("MENU_MAPPING_ENABLED", comment: "Status menu: mapping toggle"),
                action: #selector(toggleMappingEnabled(_:)),
                keyEquivalent: ""
            )
            toggleItem.target = self
            toggleItem.state = monitor.mappingEnabled ? .on : .off
            menu.addItem(toggleItem)

            menu.addItem(.separator())

            // 当前映射列表
            for paddle in ControllerMonitor.Paddle.allCases {
                let fKey = config.mapping(for: paddle) ?? "None"
                let row = NSMenuItem(title: "\(paddle.shortName) → \(fKey)", action: nil, keyEquivalent: "")
                row.isEnabled = false
                menu.addItem(row)
            }
        } else {
            let emptyItem = NSMenuItem(
                title: NSLocalizedString("MENU_NO_CONTROLLER", comment: "Status menu: no controller"),
                action: nil,
                keyEquivalent: ""
            )
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        }

        menu.addItem(.separator())

        let openItem = NSMenuItem(
            title: NSLocalizedString("MENU_OPEN_APP", comment: "Status menu: open main window"),
            action: #selector(openMainWindowAction),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: NSLocalizedString("MENU_QUIT_APP", comment: "Status menu: quit app"),
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func toggleMappingEnabled(_ sender: NSMenuItem) {
        monitor.mappingEnabled.toggle()
        // 直接更新当前菜单项勾选状态 (菜单正在跟踪时不重建整个菜单)
        sender.state = monitor.mappingEnabled ? .on : .off
    }

    @objc private func openMainWindowAction() {
        showMainWindow()
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }

    // MARK: - Main Window

    /// 打开 (或聚焦) 主窗口
    func showMainWindow() {
        if mainWindow == nil {
            mainWindow = makeMainWindow()
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    private func makeMainWindow() -> NSWindow {
        let hosting = NSHostingController(
            rootView: ContentView(
                monitor: monitor,
                config: config,
                permissionChecker: permissionChecker,
                launchAtLogin: launchAtLogin
            )
        )

        let window = NSWindow(contentViewController: hosting)
        window.title = "Paddle Mapper"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false   // 关闭后仍保留实例, 便于再次打开
        window.isRestorable = false           // 不使用系统窗口状态恢复 (窗口由 App 自己管理)
        window.contentMinSize = NSSize(width: 780, height: 500)
        window.setContentSize(NSSize(width: 900, height: 600))
        window.center()
        window.delegate = self
        return window
    }

    // MARK: - Window Delegate

    func windowWillClose(_ notification: Notification) {
        // willClose 时窗口仍然 isVisible == true, 必须延后到下一个 runloop tick 再判断
        DispatchQueue.main.async { [weak self] in
            self?.updateActivationPolicy()
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        updateActivationPolicy()
    }

    /// 主窗口可见 → .regular (显示 Dock 图标); 否则 .accessory (隐藏 Dock 图标)。
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

    // MARK: - App Lifecycle

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false  // 关闭窗口后继续驻留菜单栏
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }

    // MARK: - Main Menu (窗口可见时 Dock 菜单)

    /// AppKit 启动方式不会自动创建主菜单, 这里手工构建最小可用菜单 (退出 / 关闭 / 最小化)。
    private func buildMainMenu() {
        let mainMenu = NSMenu()

        // ─── 应用菜单 ───
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Paddle Mapper")
        appMenu.autoenablesItems = false

        let hideItem = NSMenuItem(
            title: NSLocalizedString("MENU_HIDE_APP", comment: "App menu: hide"),
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        hideItem.target = NSApp
        appMenu.addItem(hideItem)

        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: NSLocalizedString("MENU_QUIT_APP", comment: "App menu: quit"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        appMenu.addItem(quitItem)

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // ─── 窗口菜单 ───
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: NSLocalizedString("MENU_WINDOW", comment: "Menu bar: window menu"))
        windowMenu.autoenablesItems = false

        let minimizeItem = NSMenuItem(
            title: NSLocalizedString("MENU_MINIMIZE", comment: "Window menu: minimize"),
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )
        windowMenu.addItem(minimizeItem)

        let closeItem = NSMenuItem(
            title: NSLocalizedString("MENU_CLOSE_WINDOW", comment: "Window menu: close"),
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        windowMenu.addItem(closeItem)

        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }
}

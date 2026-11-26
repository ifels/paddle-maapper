import AppKit

// PaddleMapper 入口 (macOS 12+ 兼容)
//
// 原实现使用 `PaddleMapperApp.main()` (SwiftUI App 生命周期), 但其中用到的
// `MenuBarExtra` / `Window` scene / `openWindow` 均为 macOS 13+ API,
// 无法在 macOS 12 (Monterey) 上编译和运行。
//
// 因此改为纯 AppKit 启动流程: 由 AppDelegate 手动管理状态栏与主窗口。

let application = NSApplication.shared
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.setActivationPolicy(.accessory)

// 单实例保护: 通过 LaunchAgent (开机启动) 或 LaunchServices 重复拉起时,
// 只激活已存在的实例, 避免出现多个菜单栏图标 / 多次按键模拟。
let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.ifels.controlflex.paddlemapper"
let currentPID = ProcessInfo.processInfo.processIdentifier
let otherInstances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
    .filter { $0.processIdentifier != currentPID }

if let existingInstance = otherInstances.first {
    existingInstance.activate(options: [.activateIgnoringOtherApps])
    exit(0)
}

application.run()

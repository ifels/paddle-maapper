# 特性：Dock图标按窗口可见性动态显隐

## 背景
PaddleMapper是菜单栏常驻型应用，`Resources/Info.plist`中声明了：
```xml
<key>LSUIElement</key>
<true/>
```

`LSUIElement = true`把进程标记为Accessory (UI Element)应用，系统因此：
- 不在Dock显示图标
- 不在Cmd+Tab应用切换器中出现
- 没有自己的主菜单栏

但用户从菜单栏点击"Open PaddleMapper"弹出主设置窗口后，希望在Dock上看到该应用、能切到它、能用Cmd+Tab切换 —— 这是LSUIElement应用的天然短板。

## 方案对比
| 方案 | 做法 | 代价 |
|------|------|------|
| A. 删除 LSUIElement | 一直在Dock显示 | 失去"纯菜单栏应用"形态，启动时也会弹Dock图标 |
| B. 改用 NSWindow 子类强行 setActivationPolicy 一次 | 启动时切到 .regular 后就不再切回 | 关闭窗口后Dock图标残留，与LSUIElement初衷冲突 |
| C. 按窗口可见性动态切换 ActivationPolicy | 窗口显示 → .regular；全部关闭 → .accessory | 实现稍复杂，但行为最贴近预期 |

最终采用**方案C**：保留LSUIElement常驻菜单栏，主窗口出现时Dock出现图标，窗口关闭后Dock图标自动消失。

## 核心思路
- 启动时通过 `NSWindow.didBecomeKeyNotification` 和 `NSWindow.willCloseNotification` 监听窗口可见性变化。
- 在每次回调里重新扫描 `NSApp.windows`，根据是否还存在带标题栏的可见窗口决定目标ActivationPolicy。
- 通过 `styleMask.contains(.titled)` 过滤掉 MenuBarExtra 弹出的无标题面板，避免误触发。
- `willClose` 触发时窗口仍标记为 `isVisible == true`，所以判断逻辑放进 `DispatchQueue.main.async`，等到runloop下一拍再扫描。

## 实现
**文件：Sources/PaddleMapper/App/PaddleMapperApp.swift**
```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
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
                // Login Item 启动: 关掉所有窗口, 仅保留菜单栏
                for window in NSApp.windows.filter({ $0.isVisible }) {
                    window.orderOut(nil)
                }
            } else {
                // 用户手动启动: 把窗口拉到前台
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
}
```

PaddleMapperApp顶部的注释也同步更新，明确"菜单栏App + 动态Dock图标"的形态：
```swift
/// 方案 B: 菜单栏 App (LSUIElement = true), Dock 图标按窗口可见性动态切换
/// - 默认 .accessory: 仅菜单栏图标, 不在 Dock / Cmd+Tab 出现
/// - 主窗口可见时切到 .regular: Dock 显示图标, 关闭窗口后回到 .accessory
/// - MenuBarExtra 始终常驻, 是窗口关闭后唯一交互入口
```

## 关键技术点
### 1. 为什么选 `didBecomeKeyNotification` + `willCloseNotification`
| 通知 | 触发时机 | 用途 |
|------|----------|------|
| didBecomeKeyNotification | 任何NSWindow成为key window | 主窗口被打开/激活时切到 .regular |
| willCloseNotification | NSWindow即将关闭 | 主窗口关闭时切回 .accessory |

只用 `didBecomeKey` 是不够的（捕获不到关闭事件）；只用 `willClose` 也不够（捕获不到打开事件）。两者组合就能覆盖窗口可见性的所有变化点。

### 2. `styleMask.contains(.titled)` 的过滤作用
MenuBarExtra 的下拉面板、SwiftUI的浮窗、状态栏附属窗口等也会出现在 `NSApp.windows` 列表里。它们没有标题栏（无 `.titled` 位），用这个条件刚好把它们过滤掉，只保留主设计窗口（声明为 `.windowStyle(.titleBar)`）。

### 3. `willClose` 时的"伪可见"问题
`willCloseNotification` 是窗口关闭之前发出的，此时 `window.isVisible` 仍为 `true`。如果同步扫描就会误判"还有窗口"，导致Dock图标不消失。解决方法是把扫描放进 `DispatchQueue.main.async`，让窗口先走完关闭流程，再做判定。

### 4. Login Item启动场景的正确性
`applicationDidFinishLaunching` 中已有逻辑：登录项启动时主动 `orderOut` 所有窗口。在那之后调用 `updateActivationPolicy()`，会正确停留在 `.accessory`，不会闪一下Dock图标。

### 5. 切换方向的差异
- `.accessory` → `.regular`：必须配合 `NSApp.activate(ignoringOtherApps: true)`，否则窗口虽出现但拿不到键盘焦点。
- `.regular` → `.accessory`：直接调用 `setActivationPolicy(.accessory)` 即可，系统自动隐藏Dock图标和应用菜单栏。无需额外清理。

### 6. 为什么不用 `NSApp.windows.count > 0`
`NSApp.windows` 在应用生命周期里几乎永远非空（包含MenuBarExtra面板、隐藏窗口等）。必须按 `isVisible` + `styleMask` 双重过滤才能拿到真正"用户感知到的窗口"。

## 行为矩阵
| 场景 | 触发动作 | ActivationPolicy | Dock图标 | 菜单栏图标 |
|------|----------|------------------|----------|------------|
| Login Item启动 | 系统在登录时拉起 | .accessory | ❌ | ✅ |
| 用户双击启动 | Finder中打开.app | .regular | ✅ | ✅ |
| 菜单栏点击"Open PaddleMapper" | 已在运行，主窗口尚未打开 | .accessory → .regular | ❌→✅ | ✅ |
| 关闭主窗口（红色按钮） | 用户关闭设置面板 | .regular → .accessory | ✅→❌ | ✅ |
| Dock图标右键→显示 | (Dock图标存在期间) | 保持 .regular | ✅ | ✅ |
| 全部窗口最小化 | 窗口仍 isVisible（被最小化但未关闭） | 保持 .regular | ✅ | ✅ |

## 验证清单
| 测试场景 | 预期结果 |
|----------|----------|
| 双击启动.app | 主窗口出现，Dock出现图标 |
| 关闭主窗口 | Dock图标消失，菜单栏仍在 |
| 菜单栏点"Open PaddleMapper" | 主窗口重新出现，Dock图标重新出现 |
| 多次开关窗口 | Dock图标随窗口反复显隐，无残留 |
| Login Item自动启动 | Dock没有图标，只有菜单栏图标 |
| 主窗口最小化（不是关闭） | Dock图标保留 |
| Cmd+Tab切换 | 窗口打开时能切到该应用，关闭后切不到 |

## 手动验证命令
```bash
# 查看当前进程的 ActivationPolicy 和窗口列表
osascript -e 'tell application "System Events" to get visible of process "PaddleMapper"'

# 重新构建并运行
./build-app.sh --fast
open build/PaddleMapper.app

# 观察 Dock 变化 (关闭主窗口后图标应在 1 秒内消失)
```

## 常见问题
**Q1: 关闭窗口后Dock图标没消失？**
确认 `willCloseNotification` 是否被监听。可在 `windowVisibilityDidChange` 里加临时日志：
```swift
@objc private func windowVisibilityDidChange(_ notification: Notification) {
    NSLog("[Dock] event=\(notification.name.rawValue) window=\(notification.object as? NSWindow)")
    DispatchQueue.main.async { [weak self] in
        self?.updateActivationPolicy()
    }
}
```

**Q2: 切到 `.accessory` 后菜单栏图标也消失了？**
MenuBarExtra 的图标由SwiftUI单独管理，不受ActivationPolicy影响。如果消失，多半是SwiftUI视图层的问题（例如 `monitor.isControllerConnected` 状态异常导致menuBarIcon渲染失败），与本特性无关。

**Q3: 切到 `.regular` 后窗口在后台没拿到焦点？**
确保 `setActivationPolicy(.regular)` 之后调用了 `NSApp.activate(ignoringOtherApps: true)`。仅切换策略不会自动激活应用。

**Q4: 多窗口场景如何扩展？**
当前只有一个 `Window(id: "main")` Scene。若未来加入第二个独立窗口（例如About窗口），只要它也是 `.titled` 风格，本逻辑无需修改 —— `hasVisibleMainWindow` 用 `contains` 判断，存在任意一个就保持 `.regular`。如果新窗口风格特殊（例如无标题栏的HUD），需要相应调整过滤条件。

**Q5: `setActivationPolicy` 在主线程之外调用会怎样？**
AppKit要求所有UI状态变更在主线程执行。本实现里所有切换路径都在主线程（`DispatchQueue.main.async` 或NotificationCenter主线程回调），无需额外同步。

## 相关文件
- `Sources/PaddleMapper/App/PaddleMapperApp.swift` — AppDelegate 中的窗口监听 + ActivationPolicy切换
- `Resources/Info.plist` — 保留 `LSUIElement = true`，作为初始策略基线
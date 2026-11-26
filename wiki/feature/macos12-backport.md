# 将最低系统版本下调到 macOS 12.0 (Monterey)

## 背景

App 原先面向 **macOS 13 (Ventura)+**，`Info.plist` 中 `LSMinimumSystemVersion = 13.0`，
代码里大量使用 macOS 13 才有的 API。而实际目标机器是：

| 项目 | 值 |
|------|-----|
| 机型 | iMac16,2 (Intel Core i5-5675R) |
| 系统 | macOS 12.7.6 (Monterey, build 21H1320) |
| 工具链 | 仅 Command Line Tools：Swift 5.7.2 / SDK 13.1，无 Xcode |

iMac16,2 的官方最高系统版本就是 macOS 12 Monterey，因此**不可能**升级到 13。
本次改造目标：最低系统 12.0，并在该机器上编译出可直接安装的 DMG。

## 一、macOS 13 → 12 的 API 替换

| 原实现 (macOS 13+) | 替换为 (macOS 12 可用) | 说明 |
|--------------------|------------------------|------|
| `MenuBarExtra` scene | `NSStatusItem` + `NSMenu` | 菜单栏入口。用 `NSMenuDelegate.menuNeedsUpdate` 每次弹出时重建，保证映射内容实时 |
| `Window("...", id: "main")` scene | `NSWindow` + `NSHostingController` | 手动管理单例窗口；`isReleasedWhenClosed = false` 支持关闭后重开 |
| `@Environment(\.openWindow)` | `AppDelegate.showMainWindow()` | 不再依赖 SwiftUI 的窗口打开机制 |
| `.windowResizability(.contentSize)` | `window.contentMinSize` | 约束最小尺寸 |
| `.defaultSize(width:height:)` | `window.setContentSize(...)` | 初始窗口 900×600 |
| `SMAppService` (登录项) | `~/Library/LaunchAgents/*.plist` | 写入 `RunAtLoad = true` 的 LaunchAgent；登录启动时带 `--login-item` 参数 |
| SwiftUI `App` 生命周期 | AppKit：`NSApplication.run()` | `main.swift` 中创建 `NSApplication` + `AppDelegate` |

同时把 `ControllerMonitor` 里两处 `#available(macOS 13.0, *)` 判断下调为
`#available(macOS 12.0, *)`——它们包裹的 `GCController.physicalInputProfile`
实际自 macOS 11 起就已可用，下调后 macOS 12 上的扳机识别与按键检测能力与 13 完全一致。

### 顺带修复的编译阻塞

1. **`Package.swift` 工具版本**：`swift-tools-version: 5.9` → `5.7`
   （本机最高只有 Swift 5.7.2，macOS 12 也装不了 Xcode 15+）
2. **ViewBuilder 10 个子视图上限**：`PermissionGuideView` / `SetupGuidePageView` 的
   `VStack` 里各有 12 个直接子视图，编译直接报
   `extra arguments at positions #11, #12 in call`。用 `Group { }` 按区块分组解决
   （`Group` 对布局透明，不影响视觉效果）。

## 二、构建方式

本机 Command Line Tools 的 SwiftPM 本身是坏的——即使 `swift package init` 新建的空包也报：

```
error: no such module 'PackageDescription'
```

（manifest 编译阶段的 `libPackageDescription.dylib` 无法被导入）
因此 `build-app.sh` 改为**直接用 `swiftc` 编译**，不再经过 `swift build`：

```bash
swiftc -O -target x86_64-apple-macos12.0 -sdk "$(xcrun --show-sdk-path)" \
       -module-name PaddleMapper $(find Sources -name '*.swift') \
       -o build/PaddleMapper -framework IOKit
```

| 命令 | 产物 |
|------|------|
| `./build-app.sh` | Release 原生架构 + `.app` + `.dmg` |
| `./build-app.sh --fast` | Debug（-Onone）快速验证 |
| `./build-app.sh --universal` | 通用二进制（Intel + Apple Silicon，两个切片 minos 均为 12.0） |
| `./build-app.sh --no-dmg` | 只生成 `.app` |

## 三、验证结果（macOS 12.7.6 实机）

- `vtool -show-build`：二进制 `minos 12.0`
- App 正常启动，主窗口正常显示，菜单栏状态栏出现手柄图标
- 关闭窗口后 App 继续驻留菜单栏，激活策略 `Regular → Accessory` 正确回落（不留 Dock 图标）
- 关闭后再次打开复用同一个窗口实例（无重复窗口）
- `--login-item` 启动：只驻留菜单栏，不弹出主窗口
- 开机启动：LaunchAgent plist 正确写入/删除（`Label` / `RunAtLoad` / `--login-item` 均正确）
- 单实例保护：重复拉起时只激活已有实例
- DMG 挂载后拖入 `/Applications` 即可安装，从 DMG 内直接运行也正常
- 中英文菜单文案正常（`en` / `zh-Hans` 两套 `.strings` 均校验通过）

## 四、遗留说明

- 未安装签名证书时使用 **ad-hoc 签名**，每次重新编译后需重新授予「辅助功能」权限。
  运行 `./setup-cert.sh` 生成稳定证书后，`build-app.sh` 会自动改用该证书签名。
- `LSMinimumSystemVersion` 已改为 `12.0`；若将来想重新支持 13+ 的新特性，
  可按 `#available(macOS 13.0, *)` 分支保留 AppKit 实现作为兜底。

## 五、辅助功能权限：为什么必须「先装证书、再授权」

实机踩坑记录（2026-11-26）：证书装好前先授权辅助功能，会出现
「系统设置里明明是勾上的，App 仍提示没有权限」。

原因链路：

1. 未装证书时 App 为 **ad-hoc 签名**，其指定要求（DR）是 `cdhash H"…"`；
2. 每次重新编译，二进制哈希变化 → DR 变化 → macOS 认为这是**另一个应用**；
3. 但「辅助功能」列表里仍留着旧条目的勾选状态 → 看起来"已授权"，实际不匹配。

装上稳定证书后，DR 变为：

```
identifier "com.ifels.controlflex.paddlemapper" and certificate root = H"d498bae8…"
```

与二进制内容无关，重新编译后 DR 不变，权限才会长期保留。

**因此正确顺序是：① 装证书 → ② 重新编译并重装 App → ③ 授权辅助功能。**
颠倒顺序只会白授权一次。该顺序已写入 App 内的引导页（顶部提示条 + 第 2/3 节顺序）。

> 注意：从 ad-hoc 版本切换到证书签名版本时，应用身份变化，
> 需要**再授权一次**；此后重编不再丢失权限。

## 六、附带修复

- `SetupGuideContent`（原 `PermissionGuideView` + `SetupGuidePageView` 合并）：两处重复的
  引导内容统一为一份，避免再次出现「弹窗版和页面版内容不一致」。
- 证书脚本路径回退逻辑修复：原先开发布局下取的是 `build/` 目录（实际脚本在上一级），
  找不到脚本时还会在终端里执行一条必然失败的命令。
  现在按「bundle Resources → 向上 3 层目录 → `~/.paddlemapper-cert`」顺序解析，
  全部缺失时弹出明确提示，而不是留下 `chmod: setup-cert.sh: No such file or directory`。

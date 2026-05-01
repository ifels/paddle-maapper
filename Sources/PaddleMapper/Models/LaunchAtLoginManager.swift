import SwiftUI
import ServiceManagement

/// 管理开机启动（Login Item）功能
/// 使用 macOS 13+ 的 SMAppService API
final class LaunchAtLoginManager: ObservableObject {
    /// 当前是否已开启开机启动
    @Published var isEnabled: Bool = false

    init() {
        refreshStatus()
    }

    /// 刷新当前状态
    func refreshStatus() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    /// 切换开机启动状态
    func toggle() {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            refreshStatus()
        } catch {
            LogWriter.log("[PaddleMapper] Failed to toggle launch at login: \(error)")
        }
    }
}

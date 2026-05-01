import SwiftUI

/// 主窗口内容：左右分栏布局
/// 左侧：导航菜单（按键绑定、按键检测、操作手册，底部系统设置）
/// 右侧：主体内容（根据左侧选中项动态切换）
struct ContentView: View {
    @ObservedObject var monitor: ControllerMonitor
    @ObservedObject var config: MappingConfig
    @ObservedObject var permissionChecker: PermissionChecker
    @ObservedObject var launchAtLogin: LaunchAtLoginManager

    /// 当前选中的页面
    @State private var selectedPage: Page = .keyMapping

    /// Shared IOKit detector reference.
    private var hidDetector: IOKitDetector {
        monitor.hidDetector ?? IOKitDetector()
    }

    var body: some View {
        HStack(spacing: 0) {
            // ===== 左侧：导航菜单 =====
            SidebarView(
                selectedPage: $selectedPage,
                monitor: monitor
            )

            // 分割线
            Divider()

            // ===== 右侧：主体内容 =====
            contentPage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 780, maxWidth: .infinity, minHeight: 500)
        .onAppear {
            monitor.mappingConfig = config
            permissionChecker.checkPermission()
            permissionChecker.startMonitoring()
        }
    }

    // MARK: - Content Page Switching

    @ViewBuilder
    private var contentPage: some View {
        switch selectedPage {
        case .keyMapping:
            KeyMappingPageView(
                monitor: monitor,
                config: config,
                permissionChecker: permissionChecker
            )

        case .keyDetection:
            KeyDetectionPageView(
                monitor: monitor,
                hidDetector: hidDetector
            )

        case .setupGuide:
            SetupGuidePageView(
                permissionChecker: permissionChecker
            )

        case .settings:
            SystemSettingsPageView(
                permissionChecker: permissionChecker,
                monitor: monitor,
                launchAtLogin: launchAtLogin
            )
        }
    }
}

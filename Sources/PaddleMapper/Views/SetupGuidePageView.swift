import SwiftUI

/// 操作手册页面：内联展示权限引导和证书安装指南（不是 Sheet）
/// 内容统一由 `SetupGuideContent` 提供（与弹出引导窗口共用）
struct SetupGuidePageView: View {
    @ObservedObject var permissionChecker: PermissionChecker

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(
                title: NSLocalizedString("SIDEBAR_SETUP_GUIDE", comment: "Setup Guide"),
                icon: "book.fill"
            )

            ScrollView {
                SetupGuideContent(permissionChecker: permissionChecker)
                    .padding(20)
            }
        }
        .onAppear {
            permissionChecker.checkCertInstalled()
        }
    }
}

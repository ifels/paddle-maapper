import SwiftUI

/// 操作引导（Sheet 弹窗版）：从主界面弹出的引导窗口
/// 内容统一由 `SetupGuideContent` 提供（与「操作手册」页面共用）
struct PermissionGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var permissionChecker: PermissionChecker

    var body: some View {
        VStack(spacing: 0) {
            // ─── 标题栏 ───
            HStack {
                Image(systemName: "book.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text(NSLocalizedString("GUIDE_TITLE", comment: "Guide page title"))
                    .font(.title2.bold())
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                SetupGuideContent(permissionChecker: permissionChecker)
                    .padding(20)
            }
        }
        .frame(width: 560, height: 640)
        .onAppear {
            permissionChecker.checkCertInstalled()
        }
    }
}

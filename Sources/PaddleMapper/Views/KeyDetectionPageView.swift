import SwiftUI

/// 按键检测页面：包装 ButtonDetectionView 并添加页面标题
struct KeyDetectionPageView: View {
    @ObservedObject var monitor: ControllerMonitor
    @ObservedObject var hidDetector: IOKitDetector

    var body: some View {
        VStack(spacing: 0) {
            // ─── 页面标题 ───
            PageHeader(
                title: NSLocalizedString("SIDEBAR_KEY_DETECTION", comment: "Key Detection"),
                icon: "keyboard"
            )

            // ─── 检测内容 ───
            ButtonDetectionView(monitor: monitor, hidDetector: hidDetector)
        }
    }
}

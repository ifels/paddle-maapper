import SwiftUI

/// 按键绑定页面：手柄状态 + 拨片按键映射配置
struct KeyMappingPageView: View {
    @ObservedObject var monitor: ControllerMonitor
    @ObservedObject var config: MappingConfig
    @ObservedObject var permissionChecker: PermissionChecker

    /// 是否显示操作引导弹窗
    @State private var showPermissionGuide: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // ─── 页面标题 ───
            PageHeader(
                title: NSLocalizedString("SIDEBAR_KEY_MAPPING", comment: "Key Mapping"),
                icon: "gamecontroller.fill"
            )

            ScrollView {
                VStack(spacing: 0) {
                    // 权限警告（仅在未授权时显示）
                    if !permissionChecker.isAccessibilityGranted {
                        permissionWarning
                            .padding(.bottom, 12)
                    }

                    // 控制器连接状态
                    ControllerStatusView(monitor: monitor)
                        .padding(.bottom, 12)

                    // 拨片映射配置
                    paddleMappingSection
                }
                .padding(20)
            }
        }
        .sheet(isPresented: $showPermissionGuide) {
            PermissionGuideView(permissionChecker: permissionChecker)
        }
    }

    // MARK: - Paddle Mapping Section

    private var paddleMappingSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Paddle Mappings")
                    .font(.headline)
                Spacer()
                Toggle("Enable", isOn: $monitor.mappingEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            if monitor.supportsPaddles {
                // 列头
                HStack(spacing: 0) {
                    Text("Paddle")
                        .frame(width: 64, alignment: .center)
                    Text("")
                        .frame(width: 32)
                    Text("Map To")
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 4)

                ForEach(ControllerMonitor.Paddle.allCases) { paddle in
                    PaddleMappingRow(
                        paddle: paddle,
                        config: config,
                        monitor: monitor
                    )
                }
                .disabled(!monitor.mappingEnabled)
                .opacity(monitor.mappingEnabled ? 1.0 : 0.4)
            } else if monitor.isControllerConnected {
                Text("This controller does not support paddles via GCXboxGamepad.")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .padding(16)
            } else {
                Text("Connect an Xbox Elite controller to configure paddles.")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .padding(16)
            }

            Divider()
                .padding(.top, 4)

            // 底部：F 键提示 + 重置按钮
            HStack {
                Text("F15-F18")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Reset") {
                    config.resetToDefaults()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Permission Warning

    private var permissionWarning: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(NSLocalizedString("ACCESSIBILITY_PERMISSION_REQUIRED", comment: "Permission warning message"))
                    .font(.subheadline)
                Spacer()
            }
            HStack {
                Button(NSLocalizedString("GRANT_PERMISSION", comment: "Grant permission button")) {
                    permissionChecker.requestAccessibility()
                }
                .buttonStyle(.borderedProminent)

                Button(NSLocalizedString("SETUP_GUIDE", comment: "Setup guide button")) {
                    showPermissionGuide = true
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3), lineWidth: 1))
    }
}

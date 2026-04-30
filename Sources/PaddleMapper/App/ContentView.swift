import SwiftUI

/// Main window content with dual-panel layout:
/// Left panel: Paddle mapping configuration (fixed width)
/// Right panel: Button detection view (shown only when detection is active)
struct ContentView: View {
    @ObservedObject var monitor: ControllerMonitor
    @ObservedObject var config: MappingConfig
    @ObservedObject var permissionChecker: PermissionChecker

    /// Whether detection panel is shown (controls right panel visibility).
    @State private var showDetectionPanel: Bool = true

    /// Shared IOKit detector reference.
    private var hidDetector: IOKitDetector {
        monitor.hidDetector ?? IOKitDetector()
    }

    var body: some View {
        HStack(spacing: 0) {
            // ===== Left Panel: Mapping Configuration =====
            VStack(spacing: 0) {
                // Permission warning
                if !permissionChecker.isAccessibilityGranted {
                    permissionWarning
                }

                // Controller status
                ControllerStatusView(monitor: monitor)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                Divider()
                    .padding(.vertical, 8)

                // Paddle mappings section
                VStack(spacing: 4) {
                    HStack {
                        Text("Paddle Mappings")
                            .font(.headline)
                        Spacer()
                        Toggle("Enable", isOn: $monitor.mappingEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                    .padding(.horizontal, 16)

                    if monitor.supportsPaddles {
                        // Column headers (no GLFW Key column)
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
                        .padding(.horizontal, 16)
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
                }

                Spacer()

                Divider()

                // Bottom bar: Reset on left, Show/Hide on right
                HStack {
                    Button("Reset") {
                        config.resetToDefaults()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Text("F15-F18")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()

                    // Show/Hide Detection panel (IOKitDetector lifecycle
                    // is managed by ControllerMonitor, this only toggles
                    // the detection panel visibility)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showDetectionPanel.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: showDetectionPanel ? "eye.slash" : "eye")
                            Text(showDetectionPanel ? "Hide Detection" : "Show Detection")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!monitor.isControllerConnected)
                }
                .padding(12)
            }
            .frame(minWidth: 408, idealWidth: 408, maxWidth: 612)
            .frame(maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))

            // ===== Right Panel: Button Detection (collapsible) =====
            if showDetectionPanel {
                Divider()
                ButtonDetectionView(
                    monitor: monitor,
                    hidDetector: hidDetector
                )
                .frame(minWidth: 408, idealWidth: 408, maxWidth: 612)
                .frame(maxHeight: .infinity)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(minWidth: showDetectionPanel ? 840 : 408, maxWidth: .infinity, minHeight: 440)
        .onAppear {
            monitor.mappingConfig = config
            permissionChecker.checkPermission()
            permissionChecker.startMonitoring()
        }
    }

    /// 是否显示操作引导页面
    @State private var showPermissionGuide: Bool = false

    /// Accessibility permission warning banner.
    private var permissionWarning: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Accessibility permission required to simulate key presses.")
                    .font(.subheadline)
                Spacer()
            }
            HStack {
                Button("Grant Permission") {
                    permissionChecker.requestAccessibility()
                }
                .buttonStyle(.borderedProminent)

                Button("操作引导") {
                    showPermissionGuide = true
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .sheet(isPresented: $showPermissionGuide) {
            PermissionGuideView(permissionChecker: permissionChecker)
        }
    }
}

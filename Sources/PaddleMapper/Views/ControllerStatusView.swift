import SwiftUI

/// Displays controller connection status and name.
struct ControllerStatusView: View {
    @ObservedObject var monitor: ControllerMonitor

    var body: some View {
        HStack(spacing: 12) {
            // Connection indicator
            Circle()
                .fill(monitor.isControllerConnected ? Color.green : Color.red)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(monitor.isControllerConnected ? "Connected" : "No Controller")
                    .font(.headline)
                if monitor.isControllerConnected {
                    Text(monitor.controllerName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Paddle support badge
            if monitor.isControllerConnected {
                if monitor.supportsPaddles {
                    Label("Paddles Supported", systemImage: "gamecontroller.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label("No Paddle Support", systemImage: "gamecontroller")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
    }
}

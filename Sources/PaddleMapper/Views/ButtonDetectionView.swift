import SwiftUI

/// Real-time button detection view (IOKit HID Raw only).
/// Embedded in the right panel of ContentView.
struct ButtonDetectionView: View {
    @ObservedObject var monitor: ControllerMonitor
    @ObservedObject var hidDetector: IOKitDetector

    /// Filter: show only active (pressed/non-zero) inputs.
    @State private var showActiveOnly: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header - HID status left-aligned, Active Only on right
            HStack {
                if hidDetector.isRunning {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("HID Live")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("(\(hidDetector.deviceCount) device\(hidDetector.deviceCount == 1 ? "" : "s"))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Toggle("Active Only", isOn: $showActiveOnly)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Content (only HID raw source)
            hidContent
        }
    }

    // MARK: - HID Content

    private var hidContent: some View {
        Group {
            if !hidDetector.isRunning {
                idleMessage("No HID device detected.\nMake sure an Xbox controller is connected.")
            } else if hidDetector.signals.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    ProgressView()
                    Text("Waiting for HID input...")
                        .foregroundColor(.secondary)
                    Text("Press any button or move any stick on your controller.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                hidSignalList
            }
        }
    }

    private var hidSignalList: some View {
        List {
            // Summary
            let activeCount = hidDetector.signals.values.filter { $0.isPressed }.count
            let paddleCount = hidDetector.signals.values.filter { $0.name.contains("Paddle") }.count

            HStack {
                Text("\(hidDetector.signals.count) HID elements, \(activeCount) active")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if paddleCount > 0 {
                    Text("• \(paddleCount) paddle(s) detected!")
                        .font(.caption)
                        .foregroundColor(.green)
                        .bold()
                }

                Spacer()

                // Device names
                ForEach(hidDetector.deviceNames, id: \.self) { name in
                    Text(name)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .background(Capsule().fill(Color.secondary.opacity(0.1)))
                }
            }

            Divider()

            // Column headers
            HStack(spacing: 0) {
                Text("Input Name")
                    .frame(width: 140, alignment: .leading)
                    .font(.caption.bold())
                Text("HID Code")
                    .frame(width: 80, alignment: .center)
                    .font(.caption.bold())
                Text("State")
                    .frame(width: 50, alignment: .center)
                    .font(.caption.bold())
                Text("Value")
                    .frame(width: 60, alignment: .trailing)
                    .font(.caption.bold())
                Spacer()
            }
            .padding(.horizontal, 4)

            // Signal rows
            ForEach(filteredHIDSignals) { signal in
                HIDSiganlRow(signal: signal)
                    .id(signal.name)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Helpers

    private var filteredHIDSignals: [IOKitDetector.HIDSignal] {
        let all = hidDetector.signalOrder.compactMap { hidDetector.signals[$0] }
        if showActiveOnly {
            return all.filter { $0.isPressed }
        }
        return all.sorted { a, b in
            if a.isPressed != b.isPressed { return a.isPressed }
            let aPaddle = a.name.contains("Paddle")
            let bPaddle = b.name.contains("Paddle")
            if aPaddle != bPaddle { return aPaddle }
            return a.name < b.name
        }
    }

    private func idleMessage(_ text: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Text(text)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .font(.subheadline)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - HID Signal Row

private struct HIDSiganlRow: View {
    let signal: IOKitDetector.HIDSignal

    var body: some View {
        HStack(spacing: 0) {
            // Name with type icon
            HStack(spacing: 4) {
                Image(systemName: signal.name.contains("Paddle") ? "rectangle.roundedbottom.fill" :
                       signal.isPressed ? "circle.fill" : "circle")
                    .font(.system(size: 8))
                    .foregroundColor(signal.name.contains("Paddle") ? .purple :
                                      signal.isPressed ? .green : .secondary)

                Text(signal.name)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(signal.name.contains("Paddle") ? .purple : .primary)
            }
            .frame(width: 140, alignment: .leading)

            // HID code
            Text(String(format: "%02X:%02X", signal.usagePage, signal.usage))
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .center)

            // State
            Text(signal.isPressed ? "ON" : "off")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundColor(signal.isPressed ? .green : .secondary)
                .frame(width: 50, alignment: .center)

            // Value
            Text(signal.displayValue)
                .font(.system(.caption, design: .monospaced))
                .frame(width: 60, alignment: .trailing)

            Spacer()
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(signal.isPressed ? Color.green.opacity(0.05) :
                     signal.name.contains("Paddle") ? Color.purple.opacity(0.03) : Color.clear)
    }
}

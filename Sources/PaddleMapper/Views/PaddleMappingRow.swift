import SwiftUI

/// A single row for mapping one paddle to a key.
/// Uses a categorized Menu for key selection (supports 100+ keys).
struct PaddleMappingRow: View {
    let paddle: ControllerMonitor.Paddle
    @ObservedObject var config: MappingConfig
    @ObservedObject var monitor: ControllerMonitor

    /// Whether this paddle is currently pressed (for visual feedback).
    private var isPressed: Bool {
        monitor.paddleStates[paddle] ?? false
    }

    /// Currently selected key name.
    private var selectedKey: String {
        config.mapping(for: paddle) ?? ""
    }

    var body: some View {
        HStack(spacing: 0) {
            // Paddle label with press indicator
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isPressed ? Color.accentColor.opacity(0.3) : Color(nsColor: .controlBackgroundColor))
                    .frame(width: 64, height: 32)

                Text(paddle.shortName)
                    .font(.system(.callout, design: .monospaced).bold())
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isPressed ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isPressed ? 2 : 1)
            )
            .padding(.trailing, 12)

            // Arrow
            Image(systemName: "arrow.right")
                .foregroundColor(.secondary)
                .frame(width: 20)

            // Key selection Menu
            Menu {
                ForEach(KeyCodeMapper.keysByCategory, id: \.0) { category, keys in
                    Menu(category) {
                        ForEach(keys) { entry in
                            Button(action: {
                                config.setMapping(paddle: paddle, fKeyName: entry.name)
                            }) {
                                if entry.name == selectedKey {
                                    Text("✓ \(entry.name)")
                                } else {
                                    Text(entry.name)
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedKey.isEmpty ? "None" : selectedKey)
                        .font(.system(.callout, design: .monospaced))
                        .frame(minWidth: 60, alignment: .leading)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)


        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
        .background(isPressed ? Color.accentColor.opacity(0.05) : Color.clear)
    }
}

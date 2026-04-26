import Foundation
import Combine

/// Manages paddle-to-F-key mapping configuration.
/// Persisted via UserDefaults.
final class MappingConfig: ObservableObject {
    /// Mapping from paddle to F-key name (e.g. "P1" -> "F13").
    @Published var mappings: [String: String]

    /// UserDefaults key for persistence.
    private static let storageKey = "com.ifels.controlflex.paddlemapper.mappings"

    /// Default mappings: P1->F15, P2->F16, P3->F17, P4->F18
    private static let defaultMappings: [String: String] = [
        "P1": "F15",
        "P2": "F16",
        "P3": "F17",
        "P4": "F18",
    ]

    init() {
        // Load from UserDefaults or use defaults
        if let saved = UserDefaults.standard.dictionary(forKey: Self.storageKey) as? [String: String] {
            mappings = saved
        } else {
            mappings = Self.defaultMappings
        }
    }

    /// Get the mapped F-key name for a paddle.
    func mapping(for paddle: ControllerMonitor.Paddle) -> String? {
        mappings[paddle.shortName]
    }

    /// Set the mapped F-key for a paddle.
    func setMapping(paddle: ControllerMonitor.Paddle, fKeyName: String) {
        mappings[paddle.shortName] = fKeyName
        save()
    }

    /// Clear a paddle mapping.
    func clearMapping(paddle: ControllerMonitor.Paddle) {
        mappings.removeValue(forKey: paddle.shortName)
        save()
    }

    /// Save current mappings to UserDefaults.
    func save() {
        UserDefaults.standard.set(mappings, forKey: Self.storageKey)
    }

    /// Reset all mappings to defaults.
    func resetToDefaults() {
        mappings = Self.defaultMappings
        save()
    }
}

import Carbon.HIToolbox
import CoreGraphics

/// Maps key names to macOS virtual keycodes / mouse buttons.
/// Supports keyboard keys (F1-F20, A-Z, digits, modifiers, special keys)
/// and mouse buttons (Left, Right, Middle, Button4, Button5).
struct KeyCodeMapper {
    /// Kind of input: keyboard key or mouse button.
    enum KeyKind: String, Hashable {
        case keyboard = "keyboard"
        case mouse = "mouse"
    }

    /// A single mappable key entry.
    struct KeyEntry: Identifiable, Hashable {
        let name: String       // e.g. "F13", "A", "Mouse Left"
        let kind: KeyKind
        let code: UInt16       // macOS virtual keycode or mouse button number
        let category: String   // display group name
        var id: String { name }
    }

    // MARK: - All Keys

    /// All available keys in category order.
    static let allKeys: [KeyEntry] = {
        var keys: [KeyEntry] = []

        // --- Function Keys ---
        keys += [
            KeyEntry(name: "F1",  kind: .keyboard, code: UInt16(kVK_F1),  category: "Function Keys"),
            KeyEntry(name: "F2",  kind: .keyboard, code: UInt16(kVK_F2),  category: "Function Keys"),
            KeyEntry(name: "F3",  kind: .keyboard, code: UInt16(kVK_F3),  category: "Function Keys"),
            KeyEntry(name: "F4",  kind: .keyboard, code: UInt16(kVK_F4),  category: "Function Keys"),
            KeyEntry(name: "F5",  kind: .keyboard, code: UInt16(kVK_F5),  category: "Function Keys"),
            KeyEntry(name: "F6",  kind: .keyboard, code: UInt16(kVK_F6),  category: "Function Keys"),
            KeyEntry(name: "F7",  kind: .keyboard, code: UInt16(kVK_F7),  category: "Function Keys"),
            KeyEntry(name: "F8",  kind: .keyboard, code: UInt16(kVK_F8),  category: "Function Keys"),
            KeyEntry(name: "F9",  kind: .keyboard, code: UInt16(kVK_F9),  category: "Function Keys"),
            KeyEntry(name: "F10", kind: .keyboard, code: UInt16(kVK_F10), category: "Function Keys"),
            KeyEntry(name: "F11", kind: .keyboard, code: UInt16(kVK_F11), category: "Function Keys"),
            KeyEntry(name: "F12", kind: .keyboard, code: UInt16(kVK_F12), category: "Function Keys"),
            KeyEntry(name: "F13", kind: .keyboard, code: UInt16(kVK_F13), category: "Function Keys"),
            KeyEntry(name: "F14", kind: .keyboard, code: UInt16(kVK_F14), category: "Function Keys"),
            KeyEntry(name: "F15", kind: .keyboard, code: UInt16(kVK_F15), category: "Function Keys"),
            KeyEntry(name: "F16", kind: .keyboard, code: UInt16(kVK_F16), category: "Function Keys"),
            KeyEntry(name: "F17", kind: .keyboard, code: UInt16(kVK_F17), category: "Function Keys"),
            KeyEntry(name: "F18", kind: .keyboard, code: UInt16(kVK_F18), category: "Function Keys"),
            KeyEntry(name: "F19", kind: .keyboard, code: UInt16(kVK_F19), category: "Function Keys"),
            KeyEntry(name: "F20", kind: .keyboard, code: UInt16(kVK_F20), category: "Function Keys"),
        ]

        // --- Letters ---
        keys += [
            KeyEntry(name: "A", kind: .keyboard, code: UInt16(kVK_ANSI_A), category: "Letters"),
            KeyEntry(name: "B", kind: .keyboard, code: UInt16(kVK_ANSI_B), category: "Letters"),
            KeyEntry(name: "C", kind: .keyboard, code: UInt16(kVK_ANSI_C), category: "Letters"),
            KeyEntry(name: "D", kind: .keyboard, code: UInt16(kVK_ANSI_D), category: "Letters"),
            KeyEntry(name: "E", kind: .keyboard, code: UInt16(kVK_ANSI_E), category: "Letters"),
            KeyEntry(name: "F", kind: .keyboard, code: UInt16(kVK_ANSI_F), category: "Letters"),
            KeyEntry(name: "G", kind: .keyboard, code: UInt16(kVK_ANSI_G), category: "Letters"),
            KeyEntry(name: "H", kind: .keyboard, code: UInt16(kVK_ANSI_H), category: "Letters"),
            KeyEntry(name: "I", kind: .keyboard, code: UInt16(kVK_ANSI_I), category: "Letters"),
            KeyEntry(name: "J", kind: .keyboard, code: UInt16(kVK_ANSI_J), category: "Letters"),
            KeyEntry(name: "K", kind: .keyboard, code: UInt16(kVK_ANSI_K), category: "Letters"),
            KeyEntry(name: "L", kind: .keyboard, code: UInt16(kVK_ANSI_L), category: "Letters"),
            KeyEntry(name: "M", kind: .keyboard, code: UInt16(kVK_ANSI_M), category: "Letters"),
            KeyEntry(name: "N", kind: .keyboard, code: UInt16(kVK_ANSI_N), category: "Letters"),
            KeyEntry(name: "O", kind: .keyboard, code: UInt16(kVK_ANSI_O), category: "Letters"),
            KeyEntry(name: "P", kind: .keyboard, code: UInt16(kVK_ANSI_P), category: "Letters"),
            KeyEntry(name: "Q", kind: .keyboard, code: UInt16(kVK_ANSI_Q), category: "Letters"),
            KeyEntry(name: "R", kind: .keyboard, code: UInt16(kVK_ANSI_R), category: "Letters"),
            KeyEntry(name: "S", kind: .keyboard, code: UInt16(kVK_ANSI_S), category: "Letters"),
            KeyEntry(name: "T", kind: .keyboard, code: UInt16(kVK_ANSI_T), category: "Letters"),
            KeyEntry(name: "U", kind: .keyboard, code: UInt16(kVK_ANSI_U), category: "Letters"),
            KeyEntry(name: "V", kind: .keyboard, code: UInt16(kVK_ANSI_V), category: "Letters"),
            KeyEntry(name: "W", kind: .keyboard, code: UInt16(kVK_ANSI_W), category: "Letters"),
            KeyEntry(name: "X", kind: .keyboard, code: UInt16(kVK_ANSI_X), category: "Letters"),
            KeyEntry(name: "Y", kind: .keyboard, code: UInt16(kVK_ANSI_Y), category: "Letters"),
            KeyEntry(name: "Z", kind: .keyboard, code: UInt16(kVK_ANSI_Z), category: "Letters"),
        ]

        // --- Numbers ---
        keys += [
            KeyEntry(name: "0", kind: .keyboard, code: UInt16(kVK_ANSI_0), category: "Numbers"),
            KeyEntry(name: "1", kind: .keyboard, code: UInt16(kVK_ANSI_1), category: "Numbers"),
            KeyEntry(name: "2", kind: .keyboard, code: UInt16(kVK_ANSI_2), category: "Numbers"),
            KeyEntry(name: "3", kind: .keyboard, code: UInt16(kVK_ANSI_3), category: "Numbers"),
            KeyEntry(name: "4", kind: .keyboard, code: UInt16(kVK_ANSI_4), category: "Numbers"),
            KeyEntry(name: "5", kind: .keyboard, code: UInt16(kVK_ANSI_5), category: "Numbers"),
            KeyEntry(name: "6", kind: .keyboard, code: UInt16(kVK_ANSI_6), category: "Numbers"),
            KeyEntry(name: "7", kind: .keyboard, code: UInt16(kVK_ANSI_7), category: "Numbers"),
            KeyEntry(name: "8", kind: .keyboard, code: UInt16(kVK_ANSI_8), category: "Numbers"),
            KeyEntry(name: "9", kind: .keyboard, code: UInt16(kVK_ANSI_9), category: "Numbers"),
        ]

        // --- Modifiers ---
        keys += [
            KeyEntry(name: "L-Shift",  kind: .keyboard, code: UInt16(kVK_Shift),        category: "Modifiers"),
            KeyEntry(name: "R-Shift",  kind: .keyboard, code: UInt16(kVK_RightShift),   category: "Modifiers"),
            KeyEntry(name: "L-Ctrl",   kind: .keyboard, code: UInt16(kVK_Control),      category: "Modifiers"),
            KeyEntry(name: "R-Ctrl",   kind: .keyboard, code: UInt16(kVK_RightControl), category: "Modifiers"),
            KeyEntry(name: "L-Alt",    kind: .keyboard, code: UInt16(kVK_Option),       category: "Modifiers"),
            KeyEntry(name: "R-Alt",    kind: .keyboard, code: UInt16(kVK_RightOption),  category: "Modifiers"),
            KeyEntry(name: "L-Cmd",    kind: .keyboard, code: UInt16(kVK_Command),      category: "Modifiers"),
            KeyEntry(name: "R-Cmd",    kind: .keyboard, code: UInt16(kVK_RightCommand), category: "Modifiers"),
            KeyEntry(name: "Caps Lock",kind: .keyboard, code: UInt16(kVK_CapsLock),     category: "Modifiers"),
            KeyEntry(name: "Tab",      kind: .keyboard, code: UInt16(kVK_Tab),          category: "Modifiers"),
        ]

        // --- Special Keys ---
        keys += [
            KeyEntry(name: "Space",      kind: .keyboard, code: UInt16(kVK_Space),        category: "Special"),
            KeyEntry(name: "Enter",      kind: .keyboard, code: UInt16(kVK_Return),       category: "Special"),
            KeyEntry(name: "Backspace",  kind: .keyboard, code: UInt16(kVK_Delete),        category: "Special"),
            KeyEntry(name: "Delete",     kind: .keyboard, code: UInt16(kVK_ForwardDelete), category: "Special"),
            KeyEntry(name: "Escape",     kind: .keyboard, code: UInt16(kVK_Escape),        category: "Special"),
            KeyEntry(name: "Insert",     kind: .keyboard, code: UInt16(kVK_Help),          category: "Special"),
            KeyEntry(name: "Home",       kind: .keyboard, code: UInt16(kVK_Home),          category: "Special"),
            KeyEntry(name: "End",        kind: .keyboard, code: UInt16(kVK_End),           category: "Special"),
            KeyEntry(name: "Page Up",    kind: .keyboard, code: UInt16(kVK_PageUp),        category: "Special"),
            KeyEntry(name: "Page Down",  kind: .keyboard, code: UInt16(kVK_PageDown),      category: "Special"),
        ]

        // --- Navigation ---
        keys += [
            KeyEntry(name: "↑", kind: .keyboard, code: UInt16(kVK_UpArrow),    category: "Navigation"),
            KeyEntry(name: "↓", kind: .keyboard, code: UInt16(kVK_DownArrow),  category: "Navigation"),
            KeyEntry(name: "←", kind: .keyboard, code: UInt16(kVK_LeftArrow),  category: "Navigation"),
            KeyEntry(name: "→", kind: .keyboard, code: UInt16(kVK_RightArrow), category: "Navigation"),
        ]

        // --- Mouse Buttons ---
        keys += [
            KeyEntry(name: "Mouse Left",   kind: .mouse, code: 0, category: "Mouse"),
            KeyEntry(name: "Mouse Right",  kind: .mouse, code: 1, category: "Mouse"),
            KeyEntry(name: "Mouse Middle", kind: .mouse, code: 2, category: "Mouse"),
            KeyEntry(name: "Mouse Btn4",   kind: .mouse, code: 3, category: "Mouse"),
            KeyEntry(name: "Mouse Btn5",   kind: .mouse, code: 4, category: "Mouse"),
        ]

        return keys
    }()

    /// Category display order.
    static let categories: [String] = [
        "Function Keys", "Letters", "Numbers", "Modifiers", "Special", "Navigation", "Mouse"
    ]

    /// Keys grouped by category (preserving order).
    static let keysByCategory: [(String, [KeyEntry])] = {
        var result: [(String, [KeyEntry])] = []
        for cat in categories {
            let keys = allKeys.filter { $0.category == cat }
            if !keys.isEmpty {
                result.append((cat, keys))
            }
        }
        return result
    }()

    // MARK: - Lookup

    /// Lookup key entry by name.
    static func key(for name: String) -> KeyEntry? {
        allKeys.first { $0.name == name }
    }

    /// Lookup key entry by virtual keycode.
    static func key(forCode code: UInt16) -> KeyEntry? {
        allKeys.first { $0.code == code }
    }

    // MARK: - GLFW Key Name

    /// GLFW key name used by ControlFlex Minecraft mod.
    static func glfwKeyName(for name: String) -> String {
        guard let entry = key(for: name) else { return name.lowercased() }
        switch entry.kind {
        case .keyboard:
            return "key.keyboard.\(glfwKeyboardName(name))"
        case .mouse:
            return "key.mouse.\(glfwMouseName(name))"
        }
    }

    /// Map key name to GLFW keyboard key identifier.
    private static func glfwKeyboardName(_ name: String) -> String {
        switch name {
        // Function keys
        case "F1"..."F20": return name.lowercased()
        // Single letters
        case "A"..."Z": return name.lowercased()
        // Digits
        case "0"..."9": return name
        // Modifiers
        case "L-Shift":  return "left_shift"
        case "R-Shift":  return "right_shift"
        case "L-Ctrl":   return "left_control"
        case "R-Ctrl":   return "right_control"
        case "L-Alt":    return "left_alt"
        case "R-Alt":    return "right_alt"
        case "L-Cmd":    return "left_super"
        case "R-Cmd":    return "right_super"
        case "Caps Lock":return "caps_lock"
        case "Tab":      return "tab"
        // Special
        case "Space":     return "space"
        case "Enter":     return "enter"
        case "Backspace": return "backspace"
        case "Delete":    return "delete"
        case "Escape":    return "escape"
        case "Insert":    return "insert"
        case "Home":      return "home"
        case "End":       return "end"
        case "Page Up":   return "page_up"
        case "Page Down": return "page_down"
        // Navigation
        case "↑": return "up"
        case "↓": return "down"
        case "←": return "left"
        case "→": return "right"
        default:  return name.lowercased()
        }
    }

    /// Map mouse key name to GLFW mouse button identifier.
    private static func glfwMouseName(_ name: String) -> String {
        switch name {
        case "Mouse Left":   return "button_left"
        case "Mouse Right":  return "button_right"
        case "Mouse Middle": return "button_middle"
        case "Mouse Btn4":   return "button_4"
        case "Mouse Btn5":   return "button_5"
        default: return name.lowercased()
        }
    }
}

import CoreGraphics

/// Simulates keyboard and mouse events via CGEvent.
/// Requires Accessibility permission (checked by PermissionChecker).
final class KeyEventSender {
    // MARK: - Keyboard Events

    /// Simulate a key-down event for the given virtual keycode.
    static func keyDown(virtualKey: UInt16) {
        guard PermissionChecker.isAccessibilityGranted() else {
            LogWriter.log("[PaddleMapper] ERROR: Accessibility permission not granted, cannot simulate key")
            return
        }
        let source = CGEventSource(stateID: .hidSystemState)
        let event = CGEvent(keyboardEventSource: source,
                            virtualKey: virtualKey,
                            keyDown: true)
        event?.post(tap: .cghidEventTap)
    }

    /// Simulate a key-up event for the given virtual keycode.
    static func keyUp(virtualKey: UInt16) {
        guard PermissionChecker.isAccessibilityGranted() else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        let event = CGEvent(keyboardEventSource: source,
                            virtualKey: virtualKey,
                            keyDown: false)
        event?.post(tap: .cghidEventTap)
    }

    // MARK: - Mouse Button Events

    /// Simulate a mouse button down event.
    /// - Parameter button: 0=left, 1=right, 2=middle, 3=btn4, 4=btn5
    static func mouseDown(button: UInt16) {
        guard PermissionChecker.isAccessibilityGranted() else {
            LogWriter.log("[PaddleMapper] ERROR: Accessibility permission not granted, cannot simulate mouse")
            return
        }
        let source = CGEventSource(stateID: .hidSystemState)
        let location = NSEvent.mouseLocation
        // Convert from AppKit screen coordinates (origin bottom-left) to CGEvent coordinates (origin top-left)
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        let cgPoint = CGPoint(x: location.x, y: screenHeight - location.y)

        let eventType: CGEventType
        let cgButton: CGMouseButton
        switch button {
        case 0: eventType = .leftMouseDown;  cgButton = .left
        case 1: eventType = .rightMouseDown; cgButton = .right
        case 2: eventType = .otherMouseDown;  cgButton = .center
        default: eventType = .otherMouseDown;  cgButton = CGMouseButton(rawValue: UInt32(button)) ?? .center
        }

        let event = CGEvent(mouseEventSource: source, mouseType: eventType,
                             mouseCursorPosition: cgPoint, mouseButton: cgButton)
        event?.post(tap: .cghidEventTap)
    }

    /// Simulate a mouse button up event.
    static func mouseUp(button: UInt16) {
        guard PermissionChecker.isAccessibilityGranted() else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        let location = NSEvent.mouseLocation
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        let cgPoint = CGPoint(x: location.x, y: screenHeight - location.y)

        let eventType: CGEventType
        let cgButton: CGMouseButton
        switch button {
        case 0: eventType = .leftMouseUp;  cgButton = .left
        case 1: eventType = .rightMouseUp; cgButton = .right
        case 2: eventType = .otherMouseUp;  cgButton = .center
        default: eventType = .otherMouseUp;  cgButton = CGMouseButton(rawValue: UInt32(button)) ?? .center
        }

        let event = CGEvent(mouseEventSource: source, mouseType: eventType,
                             mouseCursorPosition: cgPoint, mouseButton: cgButton)
        event?.post(tap: .cghidEventTap)
    }

    // MARK: - Unified Key Entry Events

    /// Simulate a key-down event for a KeyEntry (keyboard or mouse).
    static func keyEntryDown(_ entry: KeyCodeMapper.KeyEntry) {
        switch entry.kind {
        case .keyboard: keyDown(virtualKey: entry.code)
        case .mouse:    mouseDown(button: entry.code)
        }
    }

    /// Simulate a key-up event for a KeyEntry (keyboard or mouse).
    static func keyEntryUp(_ entry: KeyCodeMapper.KeyEntry) {
        switch entry.kind {
        case .keyboard: keyUp(virtualKey: entry.code)
        case .mouse:    mouseUp(button: entry.code)
        }
    }

    /// Simulate a complete press (down + up) for the given key name.
    static func pressKey(named name: String) {
        guard let entry = KeyCodeMapper.key(for: name) else { return }
        keyEntryDown(entry)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            keyEntryUp(entry)
        }
    }
}

import AppKit

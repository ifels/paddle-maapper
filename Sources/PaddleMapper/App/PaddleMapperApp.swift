import SwiftUI

/// SwiftUI App declaration (no @main - main entry is in main.swift)
struct PaddleMapperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var monitor = ControllerMonitor()
    @StateObject private var config = MappingConfig()
    @StateObject private var permissionChecker = PermissionChecker()

    var body: some Scene {
        WindowGroup(for: String.self) { data in
            ContentView(
                monitor: monitor,
                config: config,
                permissionChecker: permissionChecker
            )
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 840, height: 520)
        .commands {
            // Remove "New Window" from File menu since we only want one window
            CommandGroup(replacing: .newItem) { }
        }

        // Menu bar status item
        MenuBarExtra("Paddle Mapper", systemImage: menuBarIcon) {
            MenuBarContent(
                monitor: monitor,
                config: config
            )
        }
    }

    // MARK: - Menu Bar

    private var menuBarIcon: String {
        monitor.isControllerConnected
            ? (monitor.supportsPaddles ? "gamecontroller.fill" : "gamecontroller")
            : "gamecontroller"
    }
}

// MARK: - Menu Bar Content View

/// Separate view so we can use @Environment(\.openWindow)
struct MenuBarContent: View {
    @ObservedObject var monitor: ControllerMonitor
    @ObservedObject var config: MappingConfig
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            if monitor.isControllerConnected {
                Text(monitor.controllerName)
                    .font(.caption)

                Toggle("Mapping Enabled", isOn: $monitor.mappingEnabled)

                Divider()

                ForEach(ControllerMonitor.Paddle.allCases) { paddle in
                    let fKey = config.mapping(for: paddle) ?? "None"
                    Text("\(paddle.shortName) → \(fKey)")
                }
            } else {
                Text("No Controller Connected")
            }

            Divider()

            Button("Open Paddle Mapper") {
                // Bring app to front; reopen window if needed
                NSApp.activate(ignoringOtherApps: true)
                // If no visible windows, ask WindowGroup to create one
                let hasVisibleWindow = NSApp.windows.contains { $0.isVisible && $0.canBecomeKey }
                if !hasVisibleWindow {
                    openWindow(value: "main")
                }
            }

            Divider()

            Button("Quit Paddle Mapper") {
                NSApp.terminate(nil)
            }
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Nothing special needed for normal launch
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false  // Keep running in menu bar
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applicationOpenURL(_ app: NSApplication, url: URL) {
        // Handle reopening from login item or URL scheme
        NSApp.activate(ignoringOtherApps: true)
    }
}

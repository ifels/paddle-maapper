import GameController
import Combine
import Carbon.HIToolbox

/// Monitors Xbox controller connection and paddle button state via GCController/GCXboxGamepad.
/// Detects press/release edges and triggers F-key simulation via KeyEventSender.
final class ControllerMonitor: ObservableObject {
    /// Paddle identifiers (P1-P4 matching Xbox Elite layout).
    enum Paddle: Int, CaseIterable, Identifiable {
        case p1 = 0  // Left paddle upper
        case p2 = 1  // Right paddle upper
        case p3 = 2  // Left paddle lower
        case p4 = 3  // Right paddle lower

        var id: Int { rawValue }

        var displayName: String {
            switch self {
            case .p1: return "P1 (Left Upper)"
            case .p2: return "P2 (Right Upper)"
            case .p3: return "P3 (Left Lower)"
            case .p4: return "P4 (Right Lower)"
            }
        }

        var shortName: String {
            "P\(rawValue + 1)"
        }
    }

    // MARK: - Published State

    /// Whether a compatible controller is currently connected.
    @Published var isControllerConnected: Bool = false

    /// Name of the connected controller.
    @Published var controllerName: String = "No Controller"

    /// Whether the connected controller supports paddles.
    @Published var supportsPaddles: Bool = false

    /// Current paddle button states (true = pressed).
    @Published var paddleStates: [Paddle: Bool] = [:]

    /// Whether paddle-to-key mapping is enabled.
    @Published var mappingEnabled: Bool = true

    /// Whether button detection mode is active.
    @Published var isDetecting: Bool = false

    /// All detected input elements from the controller (name -> value).
    @Published var detectedInputs: [InputSignal] = []

    /// A single input signal for display.
    struct InputSignal: Identifiable {
        let id = UUID()
        let name: String
        let value: Float        // 0.0 - 1.0 for buttons, -1.0 - 1.0 for axes
        let isPressed: Bool
        let isAxis: Bool

        var displayValue: String {
            if isAxis {
                return String(format: "%.3f", value)
            } else {
                return isPressed ? "ON" : "off"
            }
        }
    }

    // MARK: - Private State

    private var currentController: GCController?
    private var previousPaddleStates: [Paddle: Bool] = [:]
    private var pollingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Cached paddle button references from GCPhysicalInputProfile
    private var paddleButtons: [Paddle: GCControllerButtonInput] = [:]

    /// IOKit HID detector for raw report parsing (fallback when GCPhysicalInputProfile
    /// doesn't expose paddles, e.g. Xbox Elite 2 over Bluetooth).
    /// When active, paddle states are read from `rawPaddleStates` instead of GC buttons.
    var hidDetector: IOKitDetector?

    /// The mapping config reference for looking up F-key assignments.
    /// Initialized with a default MappingConfig (loaded from UserDefaults),
    /// so key mapping works even before the main window appears (e.g. login item launch).
    /// Replaced with the shared SwiftUI instance in ContentView.onAppear for live UI sync.
    var mappingConfig: MappingConfig? = MappingConfig()

    // MARK: - Init

    init() {
        // Initialize paddle states
        for paddle in Paddle.allCases {
            paddleStates[paddle] = false
            previousPaddleStates[paddle] = false
        }

        // Register for controller connection notifications
        NotificationCenter.default.addObserver(
            self, selector: #selector(controllerDidConnect),
            name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(controllerDidDisconnect),
            name: .GCControllerDidDisconnect, object: nil)

        // Check already-connected controllers
        checkExistingControllers()

        // Start polling timer (50ms = 20Hz)
        startPolling()
    }

    deinit {
        pollingTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Controller Detection

    @objc private func controllerDidConnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        handleController(controller)
    }

    @objc private func controllerDidDisconnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        if controller == currentController {
            disconnectController()
        }
    }

    private func checkExistingControllers() {
        for controller in GCController.controllers() {
            if handleController(controller) {
                break  // Use the first compatible controller
            }
        }
    }

    /// Try to use the given controller. Returns true if it's an Xbox controller with paddle support.
    @discardableResult
    private func handleController(_ controller: GCController) -> Bool {
        let name = controller.vendorName ?? "Unknown Controller"
        LogWriter.log("[PaddleMapper] Controller found: \(name)")

        currentController = controller
        controllerName = name
        isControllerConnected = true

        // Try to discover paddle buttons via GCPhysicalInputProfile (macOS 13+)
        // This works for Xbox Elite controllers that report paddle inputs
        discoverPaddleButtons(controller)

        if !paddleButtons.isEmpty {
            supportsPaddles = true
            LogWriter.log("[PaddleMapper] Xbox controller with paddle support: \(name)")
            LogWriter.log("[PaddleMapper] Discovered \(paddleButtons.count) paddle buttons")
            return true
        }

        // No paddle support found
        supportsPaddles = false
        LogWriter.log("[PaddleMapper] Controller connected but no paddle support: \(name)")

        // Start IOKit HID detector as fallback for raw report paddle parsing.
        // Xbox Elite 2 over BLE doesn't expose paddles via GCPhysicalInputProfile,
        // but the raw HID report byte 19 contains the paddle bitmask.
        if hidDetector == nil {
            let detector = IOKitDetector()
            hidDetector = detector
            detector.start()
            LogWriter.log("[PaddleMapper] Started IOKit HID detector for raw report paddle detection")
        
            // Check after a brief delay if HID elements contain paddle definitions
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self, let detector = self.hidDetector else { return }
                if detector.deviceCount > 0 {
                    // IOKitDetector found the device and enumerated elements (including paddles)
                    self.supportsPaddles = true
                    LogWriter.log("[PaddleMapper] IOKit detector found device - paddle support enabled via raw report")
                }
            }
        }

        return false
    }

    /// Discover paddle buttons via GCPhysicalInputProfile.
    /// Xbox Elite controllers expose paddles as named elements in the physical input profile.
    private func discoverPaddleButtons(_ controller: GCController) {
        paddleButtons.removeAll()

        if #available(macOS 13.0, *) {
            let profile = controller.physicalInputProfile

            // Xbox paddle button names in Apple's GameController framework
            let paddleNames: [(Paddle, String)] = [
                (.p1, "Paddle 1"),
                (.p2, "Paddle 2"),
                (.p3, "Paddle 3"),
                (.p4, "Paddle 4"),
            ]

            for (paddle, name) in paddleNames {
                if let button = profile[name] as? GCControllerButtonInput {
                    paddleButtons[paddle] = button
                    LogWriter.log("[PaddleMapper] Found paddle button: \(name)")
                }
            }

            // Also try Apple's standard Xbox paddle names
            if paddleButtons.isEmpty {
                let applePaddleNames: [(Paddle, String)] = [
                    (.p1, "Left Paddle 1"),
                    (.p2, "Right Paddle 1"),
                    (.p3, "Left Paddle 2"),
                    (.p4, "Right Paddle 2"),
                ]

                for (paddle, name) in applePaddleNames {
                    if let button = profile[name] as? GCControllerButtonInput {
                        paddleButtons[paddle] = button
                        LogWriter.log("[PaddleMapper] Found paddle button: \(name)")
                    }
                }
            }
        }
    }

    private func disconnectController() {
        LogWriter.log("[PaddleMapper] Controller disconnected: \(controllerName)")
        currentController = nil
        paddleButtons.removeAll()
        isControllerConnected = false
        supportsPaddles = false
        controllerName = "No Controller"

        // Stop and clean up IOKit HID detector
        if let detector = hidDetector {
            detector.stop()
            hidDetector = nil
            LogWriter.log("[PaddleMapper] Stopped IOKit HID detector")
        }

        // Release any held paddle keys
        for paddle in Paddle.allCases {
            if previousPaddleStates[paddle] == true {
                releasePaddle(paddle)
            }
            paddleStates[paddle] = false
            previousPaddleStates[paddle] = false
        }
    }

    // MARK: - Polling

    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.pollPaddleState()
            if self?.isDetecting == true {
                self?.pollAllInputs()
            }
        }
    }

    private func pollPaddleState() {
        guard mappingEnabled else { return }

        // Read current paddle states from available source
        let current: [Paddle: Bool]

        if !paddleButtons.isEmpty {
            // Primary: GCPhysicalInputProfile (works for USB/wired controllers)
            current = [
                .p1: paddleButtons[.p1]?.isPressed ?? false,
                .p2: paddleButtons[.p2]?.isPressed ?? false,
                .p3: paddleButtons[.p3]?.isPressed ?? false,
                .p4: paddleButtons[.p4]?.isPressed ?? false,
            ]
        } else if let detector = hidDetector, detector.isRunning {
            // Fallback: IOKit raw report parsing (Xbox Elite 2 over BLE)
            // Paddle states from byte 19 of Report ID 1
            current = [
                .p1: detector.rawPaddleStates[0] ?? false,
                .p2: detector.rawPaddleStates[1] ?? false,
                .p3: detector.rawPaddleStates[2] ?? false,
                .p4: detector.rawPaddleStates[3] ?? false,
            ]
        } else {
            return  // No paddle source available
        }

        // Detect edges and simulate keys
        for paddle in Paddle.allCases {
            let isPressed = current[paddle] ?? false
            let wasPressed = previousPaddleStates[paddle] ?? false

            if isPressed && !wasPressed {
                pressPaddle(paddle)
            } else if !isPressed && wasPressed {
                releasePaddle(paddle)
            }

            paddleStates[paddle] = isPressed
            previousPaddleStates[paddle] = isPressed
        }
    }

    // MARK: - Button Detection

    /// Start button detection mode – scans all inputs from the controller.
    func startDetection() {
        guard isControllerConnected else { return }
        isDetecting = true
        detectedInputs = []
        LogWriter.log("[PaddleMapper] Button detection started")
    }

    /// Stop button detection mode.
    func stopDetection() {
        isDetecting = false
        detectedInputs = []
        LogWriter.log("[PaddleMapper] Button detection stopped")
    }

    /// Poll all available inputs from the controller's physical input profile.
    private func pollAllInputs() {
        guard let controller = currentController else { return }

        if #available(macOS 13.0, *) {
            let profile = controller.physicalInputProfile
            var inputs: [InputSignal] = []

            // Scan all button inputs
            for (name, element) in profile.elements {
                if let button = element as? GCControllerButtonInput {
                    let pressed = button.isPressed
                    let value = button.value
                    inputs.append(InputSignal(
                        name: name,
                        value: value,
                        isPressed: pressed,
                        isAxis: false
                    ))
                } else if let axis = element as? GCControllerAxisInput {
                    let value = axis.value
                    inputs.append(InputSignal(
                        name: name,
                        value: value,
                        isPressed: abs(value) > 0.1,
                        isAxis: true
                    ))
                } else if let dpad = element as? GCControllerDirectionPad {
                    // Direction pad has xAxis and yAxis
                    let xVal = dpad.xAxis.value
                    let yVal = dpad.yAxis.value
                    inputs.append(InputSignal(
                        name: "\(name).x",
                        value: xVal,
                        isPressed: abs(xVal) > 0.1,
                        isAxis: true
                    ))
                    inputs.append(InputSignal(
                        name: "\(name).y",
                        value: yVal,
                        isPressed: abs(yVal) > 0.1,
                        isAxis: true
                    ))
                }
            }

            // Sort: pressed/active first, then by name
            detectedInputs = inputs.sorted { a, b in
                if a.isPressed != b.isPressed { return a.isPressed }
                if a.isAxis != b.isAxis { return !a.isAxis }
                return a.name < b.name
            }
        }
    }

    // MARK: - Key Simulation

    private func pressPaddle(_ paddle: Paddle) {
        guard let config = mappingConfig,
              let keyName = config.mapping(for: paddle),
              let entry = KeyCodeMapper.key(for: keyName) else { return }
        LogWriter.log("[PaddleMapper] \(paddle.shortName) pressed -> \(keyName) (\(entry.kind.rawValue) code \(entry.code))")
        KeyEventSender.keyEntryDown(entry)
    }

    private func releasePaddle(_ paddle: Paddle) {
        guard let config = mappingConfig,
              let keyName = config.mapping(for: paddle),
              let entry = KeyCodeMapper.key(for: keyName) else { return }
        LogWriter.log("[PaddleMapper] \(paddle.shortName) released -> \(keyName) (\(entry.kind.rawValue) code \(entry.code))")
        KeyEventSender.keyEntryUp(entry)
    }
}

import Foundation
import Combine
import IOKit
import IOKit.hid

/// Low-level HID input detector using IOKit.
/// Bypasses Apple's GameController framework to read raw HID reports,
/// which can detect paddle/back buttons on Xbox Elite 2 controllers
/// that GCPhysicalInputProfile does not expose (especially over Bluetooth).
final class IOKitDetector: ObservableObject {

    /// A single HID input signal for display.
    struct HIDSignal: Identifiable {
        let id = UUID()
        let usagePage: UInt32
        let usage: UInt32
        let name: String
        let value: Int   // Raw integer value from HID
        let floatValue: Float
        let isPressed: Bool
        let timestamp: TimeInterval

        var displayValue: String {
            if abs(floatValue - Float(Int(floatValue))) < 0.001 {
                return isPressed ? "ON" : "off"
            }
            return String(format: "%.3f", floatValue)
        }
    }

    // MARK: - Published State

    /// All discovered HID elements (name -> last signal).
    @Published var signals: [String: HIDSignal] = [:]

    /// Sorted list of signal names for display.
    @Published var signalOrder: [String] = []

    /// Whether detection is active.
    @Published var isRunning: Bool = false

    /// Number of HID devices found.
    @Published var deviceCount: Int = 0

    /// Names of found devices.
    @Published var deviceNames: [String] = []

    // MARK: - Private State

    private var hidManager: IOHIDManager?
    private var deviceManagers: [IOHIDManager] = []

    // Xbox vendor ID
    private let kXboxVendorID: UInt32 = 0x045E

    // HID Usage Pages
    private let kHIDPage_GenericDesktop: UInt32 = 0x01
    private let kHIDPage_Button: UInt32 = 0x09
    private let kHIDPage_Consumer: UInt32 = 0x0C
    private let kHIDPage_Vendor: UInt32 = 0xFF00

    // Xbox Elite 2 BLE raw report paddle byte offset
    // Report ID=1, total length=20: byte[19] is paddle bitmask
    // Bit0=Paddle1, Bit1=Paddle2, Bit2=Paddle3, Bit3=Paddle4
    private let kXboxBlePaddleByteOffset: Int = 19
    private let kXboxBleReportID: UInt32 = 1
    private let kXboxBleReportLength: CFIndex = 20

    // Paddle bitmask constants
    private let kPaddle1Bit: UInt8 = 0x01
    private let kPaddle2Bit: UInt8 = 0x02
    private let kPaddle3Bit: UInt8 = 0x04
    private let kPaddle4Bit: UInt8 = 0x08

    /// Raw report paddle states (0-3 for P1-P4), updated from byte 19 of Report ID 1.
    /// This is the reliable paddle detection method for Xbox Elite 2 over BLE,
    /// since IOHIDDeviceGetValue for paddle elements (0x09:0x0C-0x0F) maps to wrong bits.
    @Published var rawPaddleStates: [Int: Bool] = [0: false, 1: false, 2: false, 3: false]

    // All known tracked devices and their elements for polling
    private var trackedDevices: [IOHIDDevice] = []
    private var trackedElements: [IOHIDDevice: [(IOHIDElement, String)]] = [:]
    private var openedDevices = Set<UnsafeMutableRawPointer>()  // Track individually-opened devices for cleanup
    private var pollingTimer: Timer?

    /// Last paddle byte value for change detection logging
    private var lastPaddleByte: UInt8 = 0xFF  // Init to invalid to force first log

    // MARK: - Lifecycle

    init() {}

    deinit {
        stop()
    }

    // MARK: - Start / Stop

    func start() {
        guard !isRunning else { return }
        isRunning = true
        signals.removeAll()
        signalOrder.removeAll()
        trackedDevices.removeAll()
        trackedElements.removeAll()

        // Create HID manager matching game controllers
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)

        // Match Xbox controllers by VendorID only
        var matchingDict: [String: Any] = [:]
        matchingDict[kIOHIDVendorIDKey as String] = NSNumber(value: kXboxVendorID)

        IOHIDManagerSetDeviceMatching(manager, matchingDict as CFDictionary)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode!.rawValue)

        // Register device matching callback
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, result, sender, device in
            guard let context = context else { return }
            let detector = Unmanaged<IOKitDetector>.fromOpaque(context).takeUnretainedValue()
            detector.onDeviceMatched(device)
        }, context)

        // Register device removal callback
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, result, sender, device in
            guard let context = context else { return }
            let detector = Unmanaged<IOKitDetector>.fromOpaque(context).takeUnretainedValue()
            detector.onDeviceRemoved(device)
        }, context)

        // Register input value callback for ALL values
        IOHIDManagerRegisterInputValueCallback(manager, { context, result, sender, value in
            guard let context = context, result == kIOReturnSuccess else { return }
            let detector = Unmanaged<IOKitDetector>.fromOpaque(context).takeUnretainedValue()
            detector.onInputValue(value)
        }, context)

        // Register input REPORT callback to capture raw bytes (for GIP/paddle analysis)
        IOHIDManagerRegisterInputReportCallback(manager, { context, result, sender, type, reportID, report, reportLength in
            guard let context = context, result == kIOReturnSuccess else { return }
            let detector = Unmanaged<IOKitDetector>.fromOpaque(context).takeUnretainedValue()
            detector.onInputReport(reportID: reportID, report: report, length: reportLength)
        }, context)

        // Try to seize the device from other drivers (e.g. GameController framework)
        let seizeResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        if seizeResult != kIOReturnSuccess {
            LogWriter.log("[IOKitDetector] Seize failed (\(seizeResult)), trying normal open...")
            let openResult = IOHIDManagerOpen(manager, 0)
            if openResult != kIOReturnSuccess {
                LogWriter.log("[IOKitDetector] Failed to open HID manager: \(openResult)")
                isRunning = false
                return
            }
            LogWriter.log("[IOKitDetector] Opened without seize - callbacks may not fire for claimed devices")
        } else {
            LogWriter.log("[IOKitDetector] Seized device successfully")
        }

        hidManager = manager

        // Start a polling timer as fallback (100ms = 10Hz)
        // This reads element values directly even if callbacks don't fire
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.pollAllDevices()
        }

        LogWriter.log("[IOKitDetector] Started monitoring Xbox HID devices")
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        pollingTimer?.invalidate()
        pollingTimer = nil

        if let manager = hidManager {
            IOHIDManagerClose(manager, 0)
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode!.rawValue)
        }
        hidManager = nil
        deviceManagers.removeAll()

        // Close all individually-opened devices
        for device in trackedDevices {
            let ptr = Unmanaged.passUnretained(device).toOpaque()
            if openedDevices.contains(ptr) {
                IOHIDDeviceClose(device, 0)
            }
        }
        openedDevices.removeAll()
        trackedDevices.removeAll()
        trackedElements.removeAll()
        lastRawReportData.removeAll()
        lastPaddleByte = 0xFF
        rawPaddleStates = [0: false, 1: false, 2: false, 3: false]
        deviceCount = 0
        deviceNames.removeAll()
        signals.removeAll()
        signalOrder.removeAll()

        LogWriter.log("[IOKitDetector] Stopped")
    }

    // MARK: - Device Callbacks

    private func onDeviceMatched(_ device: IOHIDDevice) {
        let productName = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Unknown"
        let vendorID = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int ?? 0
        let productID = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int ?? 0
        let transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String ?? "Unknown"

        LogWriter.log("[IOKitDetector] Device matched: \(productName) (VID:\(vendorID) PID:\(productID) Transport:\(transport))")

        DispatchQueue.main.async { [weak self] in
            self?.deviceCount += 1
            self?.deviceNames.append(productName)
        }

        // Track this device for polling
        if !trackedDevices.contains(where: { $0 === device }) {
            trackedDevices.append(device)
        }

        // Try to open the device individually with seize.
        // Manager-level seize may fail for .app bundles without HID entitlements,
        // but individual device open often succeeds.
        var deviceOpenResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        if deviceOpenResult != kIOReturnSuccess {
            LogWriter.log("[IOKitDetector] Device seize failed (\(deviceOpenResult)), trying normal open...")
            deviceOpenResult = IOHIDDeviceOpen(device, 0)
        }
        if deviceOpenResult != kIOReturnSuccess {
            LogWriter.log("[IOKitDetector] Failed to open device: \(deviceOpenResult)")
            return
        }
        LogWriter.log("[IOKitDetector] Device opened successfully")
        openedDevices.insert(Unmanaged.passUnretained(device).toOpaque())

        // Scan all elements and cache them for polling
        guard let elements = IOHIDDeviceCopyMatchingElements(device, nil, 0) as? [IOHIDElement] else {
            LogWriter.log("[IOKitDetector] No elements found for device: \(productName)")
            return
        }

        var elementList: [(IOHIDElement, String)] = []
        LogWriter.log("[IOKitDetector] Device '\(productName)' has \(elements.count) HID elements:")
        for element in elements {
            let usagePage = IOHIDElementGetUsagePage(element)
            let usage = IOHIDElementGetUsage(element)
            let name = elementName(usagePage: usagePage, usage: usage)
            let kind = IOHIDElementGetType(element)
            elementList.append((element, name))
            LogWriter.log("[IOKitDetector]   [\(String(format: "0x%02X", usagePage)):\(String(format: "0x%03X", usage))] \(name) (type=\(kind))")
        }
        trackedElements[device] = elementList

        // Immediately do one poll to populate initial signal list
        pollDevice(device)
    }

    private func onDeviceRemoved(_ device: IOHIDDevice) {
        let productName = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Unknown"
        LogWriter.log("[IOKitDetector] Device removed: \(productName)")

        DispatchQueue.main.async { [weak self] in
            self?.deviceCount = max(0, (self?.deviceCount ?? 1) - 1)
            self?.deviceNames.removeAll { $0 == productName }
        }

        // Clean up tracked device
        trackedDevices.removeAll { $0 === device }
        trackedElements.removeValue(forKey: device)

        // Close individually-opened device
        let ptr = Unmanaged.passUnretained(device).toOpaque()
        if openedDevices.contains(ptr) {
            IOHIDDeviceClose(device, 0)
            openedDevices.remove(ptr)
            LogWriter.log("[IOKitDetector] Closed device: \(productName)")
        }
    }

    // MARK: - Input Value Callback

    private func onInputValue(_ value: IOHIDValue) {
        processValue(value)
    }

    // MARK: - Raw Input Report Callback (for GIP/paddle byte analysis)

    /// Last raw report bytes per report ID, for change detection
    private var lastRawReportData: [UInt32: Data] = [:]

    private func onInputReport(reportID: UInt32, report: UnsafePointer<UInt8>, length: CFIndex) {
        let data = Data(bytes: report, count: Int(length))

        // Only log if report content changed
        if lastRawReportData[reportID] == data {
            // Even if full report hasn't changed, still process paddle byte
            // (for cases where paddle changed but other bytes are same)
            if reportID == kXboxBleReportID && length == kXboxBleReportLength {
                let paddleByte = report[kXboxBlePaddleByteOffset]
                updatePaddleStates(paddleByte)
            }
            return
        }
        lastRawReportData[reportID] = data

        let hex = data.enumerated().map { (i, b) in
            String(format: "%02X", b)
        }.joined(separator: " ")

        LogWriter.log("[IOKitDetector] 📦 Raw Report ID=\(reportID) len=\(length): \(hex)")

        // Decode button bits from the standard Xbox BT report (Report ID 1)
        if reportID == 1 && length >= 3 {
            let byte1 = Int(report[1])
            let byte2 = Int(report[2])
            let buttons = byte1 | (byte2 << 8)

            let buttonNames = [
                "A", "B", "X", "Y", "LB", "RB", "View", "Menu",
                "LS", "RS", "Guide", "Bit11", "Bit12", "Bit13", "Bit14", "Bit15"
            ]

            var pressed: [String] = []
            for i in 0..<16 {
                if (buttons & (1 << i)) != 0 {
                    pressed.append(buttonNames[i])
                }
            }

            if !pressed.isEmpty {
                LogWriter.log("[IOKitDetector] 🎮 Buttons raw bits: \(String(format: "0x%04X", buttons)) → \(pressed.joined(separator: "+"))")
            }
        }

        // Parse paddle byte from Xbox Elite 2 BLE report
        // Byte 19 is the paddle bitmask: bit0=P1, bit1=P2, bit2=P3, bit3=P4
        if reportID == kXboxBleReportID && length == kXboxBleReportLength {
            let paddleByte = report[kXboxBlePaddleByteOffset]
            updatePaddleStates(paddleByte)
        }
    }

    /// Update paddle states from the raw report paddle byte.
    /// Also generates HIDSignal entries so the UI shows paddle state correctly.
    private func updatePaddleStates(_ paddleByte: UInt8) {
        let p1 = (paddleByte & kPaddle1Bit) != 0
        let p2 = (paddleByte & kPaddle2Bit) != 0
        let p3 = (paddleByte & kPaddle3Bit) != 0
        let p4 = (paddleByte & kPaddle4Bit) != 0

        // Log only on change
        if paddleByte != lastPaddleByte {
            let active: [String] = [
                p1 ? "P1" : nil, p2 ? "P2" : nil,
                p3 ? "P3" : nil, p4 ? "P4" : nil
            ].compactMap { $0 }
            LogWriter.log("[IOKitDetector] 🏓 Paddle byte: \(String(format: "0x%02X", paddleByte)) → \(active.isEmpty ? "none" : active.joined(separator: "+"))")
            lastPaddleByte = paddleByte
        }

        // Update published paddle states on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.rawPaddleStates[0] = p1
            self.rawPaddleStates[1] = p2
            self.rawPaddleStates[2] = p3
            self.rawPaddleStates[3] = p4

            // Also update signals dict so ButtonDetectionView shows paddle states
            let paddleInfo: [(Int, UInt32, String, Bool)] = [
                (0, 0x0C, "Paddle 1", p1),
                (1, 0x0D, "Paddle 2", p2),
                (2, 0x0E, "Paddle 3", p3),
                (3, 0x0F, "Paddle 4", p4),
            ]
            for (_, usage, name, pressed) in paddleInfo {
                let signal = HIDSignal(
                    usagePage: 0x09,
                    usage: usage,
                    name: name,
                    value: pressed ? 1 : 0,
                    floatValue: pressed ? 1.0 : 0.0,
                    isPressed: pressed,
                    timestamp: CFAbsoluteTimeGetCurrent()
                )
                let isNew = self.signals[name] == nil
                self.signals[name] = signal
                if isNew {
                    self.signalOrder.append(name)
                }
            }
        }
    }

    private func processValue(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let usagePage = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let rawValue = IOHIDValueGetIntegerValue(value)
        let timestamp = IOHIDValueGetTimeStamp(value)

        let name = elementName(usagePage: usagePage, usage: usage)

        // Determine float/pressed state
        let (floatVal, pressed) = interpretValue(
            usagePage: usagePage, usage: usage,
            rawValue: rawValue, element: element
        )

        let signal = HIDSignal(
            usagePage: usagePage,
            usage: usage,
            name: name,
            value: rawValue,
            floatValue: floatVal,
            isPressed: pressed,
            timestamp: Double(timestamp)
        )

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let isNew = self.signals[name] == nil
            self.signals[name] = signal
            if isNew {
                self.signalOrder.append(name)
            }
        }
    }

    // MARK: - Polling (fallback when callbacks don't fire)

    /// Background queue for heavy processing (not IOKit calls)
    private let pollingQueue = DispatchQueue(label: "com.paddlemapper.iokit.polling", qos: .userInteractive)
    /// Prevent overlapping poll cycles
    private var isPolling = false

    /// Poll all tracked devices by reading element values directly.
    /// IOKit calls (IOHIDDeviceGetValue) MUST happen on the main thread
    /// since the device was opened on the main run loop.
    private func pollAllDevices() {
        // Skip if previous cycle hasn't completed
        guard !isPolling else { return }
        isPolling = true

        let startTime = CFAbsoluteTimeGetCurrent()
        for device in trackedDevices {
            pollDevice(device)
        }
        isPolling = false

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        if elapsed > 10 {
            LogWriter.log("[IOKitDetector] ⚠️ Slow poll cycle: \(String(format: "%.1f", elapsed))ms")
        }
    }


    private func pollDevice(_ device: IOHIDDevice) {
        guard let elementList = trackedElements[device] else { return }

        // Collect all changed signals, then dispatch to main in one batch
        var changedSignals: [(String, HIDSignal)] = []

        for (element, name) in elementList {
            // Skip elements that can't hold values (collections, features, etc.)
            // IOHIDElementType: 1=Input_Misc, 2=Input_Button
            let rawType = IOHIDElementGetType(element).rawValue
            guard rawType == 1 || rawType == 2 else {
                continue
            }

            // Only poll game-relevant UsagePages: 0x01 (Desktop: axes), 0x09 (Button: gamepad)
            // Skip 0x07 (Keyboard) and other irrelevant pages to avoid overwhelming the HID stack
            let usagePage = IOHIDElementGetUsagePage(element)
            guard usagePage == 0x01 || usagePage == 0x09 else {
                continue
            }

            // Read current element value directly from device
            // Use optional + memoryRebound to avoid crash from implicitly unwrapped nil
            var hidValueOpt: Unmanaged<IOHIDValue>? = nil
            let getResult = withUnsafeMutablePointer(to: &hidValueOpt) { ptr in
                ptr.withMemoryRebound(to: Unmanaged<IOHIDValue>.self, capacity: 1) { reboundPtr in
                    IOHIDDeviceGetValue(device, element, reboundPtr)
                }
            }
            guard getResult == kIOReturnSuccess, let hidValue = hidValueOpt else { continue }
            let value = hidValue.takeUnretainedValue()
            let rawValue = IOHIDValueGetIntegerValue(value)
            let timestamp = CFAbsoluteTimeGetCurrent()

            let usage = IOHIDElementGetUsage(element)

            let (floatVal, pressed) = interpretValue(
                usagePage: usagePage, usage: usage,
                rawValue: rawValue, element: element
            )

            let signal = HIDSignal(
                usagePage: usagePage,
                usage: usage,
                name: name,
                value: rawValue,
                floatValue: floatVal,
                isPressed: pressed,
                timestamp: Double(timestamp)
            )

            changedSignals.append((name, signal))
        }

        // Batch update UI on main thread (one dispatch instead of N)
        if !changedSignals.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                for (name, signal) in changedSignals {
                    let isNew = self.signals[name] == nil
                    self.signals[name] = signal
                    if isNew {
                        self.signalOrder.append(name)
                    }
                }
            }
        }
    }

    // MARK: - Value Interpretation

    private func interpretValue(usagePage: UInt32, usage: UInt32, rawValue: Int, element: IOHIDElement) -> (Float, Bool) {
        if usagePage == kHIDPage_Button {
            // Button: rawValue 0 = released, 1 = pressed
            return (Float(rawValue), rawValue != 0)
        }

        // For axes, normalize using logical min/max
        let logicalMin = IOHIDElementGetLogicalMin(element)
        let logicalMax = IOHIDElementGetLogicalMax(element)

        if logicalMax > logicalMin {
            let normalized = Float(rawValue - logicalMin) / Float(logicalMax - logicalMin)
            let centered = normalized * 2.0 - 1.0  // Map to -1.0...1.0
            return (centered, abs(centered) > 0.1)
        }

        return (Float(rawValue), rawValue != 0)
    }

    // MARK: - Element Naming

    /// Map HID usage page:usage to a human-readable name.
    private func elementName(usagePage: UInt32, usage: UInt32) -> String {
        switch usagePage {
        case 0x01: // Generic Desktop
            return genericDesktopName(usage)
        case 0x09: // Button
            return buttonName(usage)
        case 0x0C: // Consumer
            return consumerName(usage)
        default:
            return String(format: "HID[\(String(format: "0x%02X", usagePage)):\(String(format: "0x%02X", usage))]")
        }
    }

    private func genericDesktopName(_ usage: UInt32) -> String {
        switch usage {
        case 0x01: return "Pointer"
        case 0x02: return "Mouse"
        case 0x04: return "Joystick"
        case 0x05: return "Game Pad"
        case 0x06: return "Keyboard"
        case 0x30: return "X Axis"
        case 0x31: return "Y Axis"
        case 0x32: return "Z Axis"
        case 0x33: return "Rx Axis"
        case 0x34: return "Ry Axis"
        case 0x35: return "Rz Axis"
        case 0x36: return "Slider"
        case 0x37: return "Dial"
        case 0x38: return "Wheel"
        case 0x39: return "Hat Switch"
        case 0x3D: return "Start"
        case 0x3E: return "Select"
        case 0x40: return "D-Pad Up"
        case 0x41: return "D-Pad Down"
        case 0x42: return "D-Pad Right"
        case 0x43: return "D-Pad Left"
        default: return String(format: "GD[0x%02X]", usage)
        }
    }

    private func buttonName(_ usage: UInt32) -> String {
        // Standard Xbox button mapping by HID usage number
        switch usage {
        case 1:  return "Btn A"
        case 2:  return "Btn B"
        case 3:  return "Btn X"
        case 4:  return "Btn Y"
        case 5:  return "LB (Bumper L)"
        case 6:  return "RB (Bumper R)"
        case 7:  return "View (Back)"
        case 8:  return "Menu (Start)"
        case 9:  return "LS Click"
        case 10: return "RS Click"
        case 11: return "Guide (Xbox)"
        case 12: return "Paddle 1"   // Xbox Elite back button
        case 13: return "Paddle 2"
        case 14: return "Paddle 3"
        case 15: return "Paddle 4"
        case 16: return "Share"
        default: return "Btn \(usage)"
        }
    }

    private func consumerName(_ usage: UInt32) -> String {
        switch usage {
        case 0x30: return "Power"
        case 0x40: return "Menu"
        case 0x41: return "Select"
        case 0x60: return "Data On Screen"
        case 0x223: return "Back"
        case 0x224: return "Forward"
        case 0x225: return "Play"
        case 0x226: return "Pause"
        default: return String(format: "Consumer[0x%03X]", usage)
        }
    }
}

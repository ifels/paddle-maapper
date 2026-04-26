import Foundation

/// Simple file logger that mirrors output to both stdout and a log file.
/// This allows `tail -f /tmp/paddlemapper.log` to see all diagnostic output
/// even when the app is launched via `open build/PaddleMapper.app` (where stdout is not visible).
enum LogWriter {
    static let logPath = "/tmp/paddlemapper.log"

    private static let queue = DispatchQueue(label: "com.paddlemapper.logwriter")
    private static var fileHandle: FileHandle?
    private static var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func log(_ message: String) {
        let ts = dateFormatter.string(from: Date())
        let line = "[\(ts)] \(message)"

        // Always print to stdout (visible in terminal)
        print(line)

        // Also write to log file (visible via tail -f)
        queue.async {
            if fileHandle == nil {
                // Create/recreate log file
                FileManager.default.createFile(atPath: logPath, contents: nil)
                fileHandle = FileHandle(forWritingAtPath: logPath)
                fileHandle?.seekToEndOfFile()
            }
            if let data = (line + "\n").data(using: .utf8) {
                fileHandle?.write(data)
            }
        }
    }

    static func flush() {
        queue.sync {
            fileHandle?.synchronizeFile()
        }
    }

    static func close() {
        queue.sync {
            fileHandle?.closeFile()
            fileHandle = nil
        }
    }
}

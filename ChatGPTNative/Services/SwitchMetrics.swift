import Foundation
import OSLog

/// Bounded, content-free observations. Durations are relative to a native selection,
/// not a promise that the display has presented a web frame.
@MainActor @Observable
final class SwitchMetrics {
    struct Event: Codable {
        let operation: UUID
        let name: String
        let milliseconds: Double
        let uptime: Double
    }
    private(set) var operation = UUID()
    private(set) var events: [Event] = []
    private var began = ContinuousClock.now
    private let logger = Logger(subsystem: "local.personal.ChatGPTNative", category: "Switching")
    func begin(_ name: String) {
        operation = UUID()
        began = .now
        record(name)
    }
    func record(_ name: String) {
        let parts = began.duration(to: .now).components
        let ms = Double(parts.seconds) * 1000 + Double(parts.attoseconds) / 1e15
        events.append(Event(operation: operation, name: name, milliseconds: ms, uptime: ProcessInfo.processInfo.systemUptime))
        if events.count > 200 { events.removeFirst(events.count - 200) }
        logger.info("switch=\(self.operation.uuidString, privacy: .public) event=\(name, privacy: .public) elapsed_ms=\(ms, privacy: .public)")
    }
}

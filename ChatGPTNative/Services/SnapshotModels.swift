import Foundation
import CryptoKit

enum ReplyState: String, Codable, Sendable {
    case complete, pageEnded, streaming, unverified, interrupted
    var label: String {
        switch self {
        case .complete: "已确认完整"
        case .pageEnded: "页面结束，完整性未确认"
        case .streaming: "流式进行中"
        case .unverified: "完成状态未确认"
        case .interrupted: "采集中断，可能不完整"
        }
    }
}

enum PageObservation: String, Codable, Sendable {
    case complete, pageEnded, streaming, unverified, interrupted, readFailure, unavailable
}

struct ObservedMessage: Codable, Sendable {
    let id: String
    let role: String
    let body: String
    let state: PageObservation
    let evidence: String?
}

struct ObservedConversation: Codable, Sendable {
    let schema: Int
    let documentID: String
    let sequence: Int
    let conversationID: String
    let pageState: PageObservation
    let messages: [ObservedMessage]
    var order: [String]? = nil
}

struct SavedMessage: Codable, Identifiable, Sendable {
    let id: String
    let role: String
    var body: String
    var fingerprint: String
    var state: ReplyState
    var lastObservation: PageObservation
    var evidence: String?
    var alternativeBody: String?
    var interruptionReason: String? = nil
    var firstSeen: Date
    var updatedAt: Date
    var order: Double

    var hasConflict: Bool { alternativeBody != nil }
    static func hash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

struct ConversationSummary: Identifiable, Sendable {
    let id: String
    let updatedAt: Date
    let messageCount: Int
    var label: String { "会话 …" + id.suffix(8) }
    var url: URL { URL(string: "https://chatgpt.com/c/\(id)")! }
}

enum SnapshotIdentity {
    static func valid(_ id: String) -> Bool { UUID(uuidString: id) != nil }
    static func conversation(in url: URL?) -> String? {
        guard let url, url.scheme == "https", url.host == "chatgpt.com" else { return nil }
        let parts = url.pathComponents
        guard parts.count >= 3, parts[parts.count - 2] == "c", valid(parts.last!) else { return nil }
        return parts.last!.lowercased()
    }
    static func isErrorText(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["无法加载此回复", "无法加载此 chatgpt 对话", "unable to load this response",
                "unable to load conversation", "something went wrong", "network error",
                "too many requests", "请求过于频繁"].contains { prefix in
            guard t.hasPrefix(prefix) else { return false }
            let tail = t.dropFirst(prefix.count)
            return tail.isEmpty || tail.first!.isWhitespace || tail.first!.isPunctuation
        }
    }
}

import SwiftUI
import OSLog

/// Per-window ownership. One NSView never moves between simultaneous windows.
@MainActor @Observable
final class BrowserWorkspace {
    private static var restoredThisLaunch = false
    private(set) var sessions: [BrowserSession]
    private(set) var active: BrowserSession
    var showRecovery = false
    var showProtectionStatus = false
    var recoveryConversation: String?
    var switchMilliseconds: Double = 0
    var warmSwitches = 0
    let library: SnapshotLibrary
    private var started = false
    private let maximumViews = 3
    private let logger = Logger(subsystem: "local.personal.ChatGPTNative", category: "Workspace")
    private let factory: @MainActor () -> BrowserSession
    private let conversationURL: (ConversationSummary) -> URL
    private let homeURL: URL

    var protectionStatus: String {
        var details = [library.enabled ? "本地快照保存：已启用" : "本地快照保存：已暂停"]
        details.append(active.observerAvailable ? "消息观察器：已安装" : "本地消息观察不可用，当前页面尚未受保护")
        let page: String = switch active.pageState {
        case .unavailable:
            active.conversationID == nil ? "当前页面尚无可识别的会话" :
                "尚未识别可保存的消息，当前页面的本地副本可能不完整"
        case .readFailure: "官方内容读取失败，已保存的本地正文仍保留"
        case .interrupted: "页面或采集已中断，本地副本可能不完整"
        case .streaming: "正在接收回复，已提交的正文增量保存在本机"
        case .unverified: "已观察到回复，完成状态未确认"
        case .pageEnded, .complete: "页面结束，完整性未确认"
        }
        details.append("当前页面：\(page)")
        let count = library.recent.first { $0.id == active.conversationID }?.messageCount ?? 0
        details.append("当前会话已保存：\(count) 条本地回复")
        if let error = active.error { details.append("页面错误：\(error)") }
        if let warning = library.warning { details.append("快照存储：\(warning)") }
        details.append("仅保存能够可靠识别的回复文本；页面结束不证明服务端已完整保存。")
        return details.joined(separator: "\n\n")
    }

    init(library: SnapshotLibrary = .shared, factory: (@MainActor () -> BrowserSession)? = nil,
         conversationURL: @escaping (ConversationSummary) -> URL = { $0.url },
         homeURL: URL = URL(string: "https://chatgpt.com/")!) {
        self.library = library
        self.factory = factory ?? { BrowserSession(loadHome: false, library: library) }
        self.conversationURL = conversationURL
        self.homeURL = homeURL
        let first = self.factory()
        active = first
        sessions = [first]
    }
    func start() async {
        guard !started else { return }
        started = true
        let restoreRecent = !Self.restoredThisLaunch
        Self.restoredThisLaunch = true
        await library.refresh()
        guard !sessions.isEmpty else { return }
        if restoreRecent, let recent = library.recent.first {
            recoveryConversation = recent.id
            showRecovery = true
            active.startOnce(at: conversationURL(recent))
        } else { active.startOnce(at: homeURL) }
    }
    func open(_ conversation: ConversationSummary) {
        let began = ContinuousClock.now
        showRecovery = false
        if let existing = sessions.first(where: {
            $0.conversationID == conversation.id && $0.matches(conversation.id)
        }) {
            active = existing
            sessions.removeAll { $0 === existing }
            sessions.append(existing)
            warmSwitches += 1
            logger.info("warm session selected; explicit loads=0")
        } else {
            let next = factory()
            active = next
            sessions.append(next)
            next.startOnce(at: conversationURL(conversation))
            while sessions.count > maximumViews { sessions.removeFirst().retire() }
            logger.info("cold session selected; explicit loads=1")
        }
        recoveryConversation = conversation.id
        let duration = began.duration(to: .now).components
        switchMilliseconds = Double(duration.seconds) * 1000 + Double(duration.attoseconds) / 1e15
    }
    func recover() {
        recoveryConversation = active.conversationID ?? library.recent.first?.id
        showRecovery = true
    }
    func close() {
        for session in sessions { session.retire() }
        sessions.removeAll()
    }
}

struct BrowserWorkspaceKey: FocusedValueKey { typealias Value = BrowserWorkspace }
extension FocusedValues {
    var browserWorkspace: BrowserWorkspace? {
        get { self[BrowserWorkspaceKey.self] }
        set { self[BrowserWorkspaceKey.self] = newValue }
    }
}

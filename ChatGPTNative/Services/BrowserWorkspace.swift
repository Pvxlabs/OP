import SwiftUI
import OSLog
import Dispatch

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
    let metrics = SwitchMetrics()
    let library: SnapshotLibrary
    private var started = false
    private(set) var localConversation: String?
    private(set) var localMessages: [SavedMessage] = []
    private(set) var localLoading = false
    private(set) var showingLocal = false
    private(set) var syncState = "idle"
    private var selection = UUID()
    private var snapshotTask: Task<Void, Never>?
    private var pressure: DispatchSourceMemoryPressure?
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
        details.append("缓存与同步：\(syncState)，保留 \(sessions.count)/\(maximumViews) 个网页视图")
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
        observe(first)
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in self?.trimInactiveSessions() }
        }
        source.resume()
        pressure = source
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
            // Restore the website silently. Local copies remain available on demand;
            // opening the app must not put recovery UI in front of the chat.
            metrics.begin("restartSilent")
            syncState = "loadingOfficial"
            active.startOnce(at: conversationURL(recent))
        } else { active.startOnce(at: homeURL) }
    }
    func open(_ conversation: ConversationSummary) {
        let began = ContinuousClock.now
        metrics.begin("selection")
        showRecovery = false
        if let existing = sessions.first(where: {
            ($0.pendingConversationID == conversation.id && ($0.webView.url == nil || $0.matches(conversation.id))) ||
                ($0.conversationID == conversation.id && $0.matches(conversation.id))
        }) {
            active = existing
            sessions.removeAll { $0 === existing }
            sessions.append(existing)
            warmSwitches += 1
            metrics.record("cacheHit")
            if existing.readableConversationID == conversation.id && existing.pageState != .readFailure && existing.pageState != .interrupted {
                clearLocal()
                syncState = "cacheHit"
            } else { presentLocal(conversation.id) }
            logger.info("warm session selected; explicit loads=0")
        } else {
            metrics.record("coldLoad")
            let next = factory()
            observe(next)
            active = next
            sessions.append(next)
            presentLocal(conversation.id)
            next.startOnce(at: conversationURL(conversation))
            while sessions.count > maximumViews { sessions.removeFirst().retire() }
            logger.info("cold session selected; explicit loads=1")
        }
        recoveryConversation = conversation.id
        metrics.record("nativeSelectionFinished")
        let duration = began.duration(to: .now).components
        switchMilliseconds = Double(duration.seconds) * 1000 + Double(duration.attoseconds) / 1e15
    }
    private func observe(_ session: BrowserSession) {
        session.didObserveContent = { [weak self, weak session] in
            guard let self, let session, session === self.active else { return }
            if session.pageState == .readFailure || session.pageState == .interrupted {
                if self.syncState != "loadFailed" { self.metrics.record("loadFailed") }
                self.syncState = "loadFailed"
            } else if let target = self.localConversation ?? session.conversationID,
                      session.readableConversationID == target, session.matches(target) {
                if self.syncState != "officialReadable" { self.metrics.record("officialBodyReadable") }
                if self.showingLocal { self.clearLocal() }
                self.syncState = "officialReadable"
            }
        }
    }
    private func presentLocal(_ id: String) {
        selection = UUID()
        let request = selection
        snapshotTask?.cancel()
        localConversation = id
        localMessages = []
        localLoading = true
        showingLocal = true
        syncState = "loadingOfficial"
        let epoch = library.clearEpoch
        snapshotTask = Task { [weak self] in
            guard let self else { return }
            let messages = await self.library.messages(id)
            guard !Task.isCancelled, self.selection == request, self.localConversation == id,
                  self.library.clearEpoch == epoch else { return }
            self.localMessages = messages
            self.localLoading = false
            self.metrics.record(messages.isEmpty ? "snapshotMiss" : "snapshotRestored")
        }
    }
    private func clearLocal() {
        selection = UUID()
        snapshotTask?.cancel()
        snapshotTask = nil
        showingLocal = false
        localLoading = false
        localConversation = nil
        localMessages = []
    }
    func revealOfficial() {
        clearLocal()
        metrics.record("officialManuallyRevealed")
    }
    func trimInactiveSessions() {
        for session in sessions where session !== active { session.retire() }
        sessions = sessions.filter { $0 === active }
        metrics.record("memoryPressureTrim")
    }
    func recover() {
        recoveryConversation = active.conversationID ?? library.recent.first?.id
        showRecovery = true
    }
    func close() {
        clearLocal()
        pressure?.cancel()
        pressure = nil
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

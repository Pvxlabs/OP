import AppKit
import SwiftUI
import Observation

struct ExecutionQueryReport: Decodable {
    var request: String = ""
    let status: String
    let reason: String
}

enum ExecutionQuery {
    static let message = "请通过 CLINX 查询本对话刚才派发的 Codex 任务，报告最新执行状态；如果已经结束，请读取并总结结果。不要重新派发任务。"
}

@MainActor @Observable
final class CEFSession: Identifiable {
    let id: Int64
    let host = NSView(frame: NSRect(x: 0, y: 0, width: 1100, height: 780))
    let initialURL: URL
    var browser: Int32 = 0
    var url: URL
    var title = "OP"
    var observerAvailable = false
    var mainWorldIsolated = false
    var pageState: PageObservation = .unavailable
    var error: String?
    var canGoBack = false
    var canGoForward = false
    var loading = true
    var readableConversation: String?
    var documentID: String?
    var sequence = 0
    var lastHTTPStatus: Int?
    var consultationHTTPFailure: Int?
    var consultationHTTPChallenge = false
    var navigationCount = 0
    var attachmentCount = 0
    var retired = false
    var flushCount = 0
    private var query: (id: String, continuation: CheckedContinuation<ExecutionQueryReport, Never>)?
    var consultationPending: (id: String, continuation: CheckedContinuation<ConsultationPageReport, Never>)?
    var hasPendingQuery: Bool { query != nil }
    func queryExecution() async -> ExecutionQueryReport {
        guard query == nil, consultationPending == nil else { return .init(status: "waiting", reason: "正在发送查询，请稍候。") }
        guard !Task.isCancelled, browser > 0, !retired, !loading, let conversation else {
            return .init(status: "waiting", reason: "请先打开并加载要查询的 ChatGPT 对话。")
        }
        let request = UUID().uuidString
        let object: [String: Any] = ["request": request, "conversation": conversation,
                                     "message": ExecutionQuery.message,
                                     "deadline": Date().addingTimeInterval(10).timeIntervalSince1970 * 1000]
        guard let data = try? JSONSerialization.data(withJSONObject: object), let json = String(data: data, encoding: .utf8) else {
            return .init(status: "waiting", reason: "无法准备查询消息。")
        }
        return await withCheckedContinuation { continuation in
            query = (request, continuation)
            json.withCString { op_cef_query(browser, $0) }
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(15))
                guard let self, query?.id == request else { return }
                finishQuery(.init(status: "uncertain", reason: "发送核验超时，请检查当前对话或输入框；不会自动重发。"))
            }
        }
    }
    func queryResult(_ json: String) {
        if let pending = consultationPending,
           let report = try? JSONDecoder().decode(ConsultationPageReport.self, from: Data(json.utf8)), report.request == pending.id {
            consultationPending = nil; pending.continuation.resume(returning: report); return
        }
        guard let report = try? JSONDecoder().decode(ExecutionQueryReport.self, from: Data(json.utf8)),
              query?.id == report.request else { return }
        finishQuery(report)
    }
    private func finishQuery(_ report: ExecutionQueryReport) {
        let pending = query; query = nil
        pending?.continuation.resume(returning: report)
    }
    private var retiredInterrupt: Task<Void, Never>?
    var conversation: String? { CEFIdentity.conversation(url) }
    init(id: Int64, url: URL) { self.id = id; initialURL = url; self.url = url }
    func mount(enabled: Bool) {
        guard browser == 0, !retired else { return }
        browser = initialURL.absoluteString.withCString { op_cef_create(Unmanaged.passUnretained(host).toOpaque(), $0, id) }
        if browser == 0 { error = "Chromium 视图创建失败"; return }
        navigationCount += 1
        op_cef_enabled(browser, enabled)
    }
    func flush() async {
        guard browser > 0, !retired else { return }
        let previous = flushCount
        op_cef_flush(browser)
        for _ in 0..<20 {
            if flushCount > previous { return }
            try? await Task.sleep(for: .milliseconds(50))
        }
        // A hung renderer must not hang the native shutdown. Saved content remains intact.
    }
    func retire(library: SnapshotLibrary) {
        guard !retired else { return }; retired = true
        // Mark interrupted before releasing the CEF view. Never upgrade a stream on eviction.
        if let conversation, let store = library.store {
            retiredInterrupt = Task { try? await store.interrupt(conversation) }
        }
        if browser != 0 { op_cef_close(browser) }
    }
}

enum CEFIdentity {
    static var fixtureOrigin: String? {
        CommandLine.arguments.first(where: { $0.hasPrefix("--self-test-origin=") }).map { String($0.dropFirst("--self-test-origin=".count)) }
    }
    static func conversation(_ url: URL) -> String? {
        if let id = SnapshotIdentity.conversation(in: url) { return id }
        guard let origin = fixtureOrigin, url.scheme == "http", url.host == "127.0.0.1",
              "http://127.0.0.1:\(url.port ?? 0)" == origin else { return nil }
        let parts = url.pathComponents
        guard parts.count == 3, parts[1] == "c", SnapshotIdentity.valid(parts[2]) else { return nil }
        return parts[2].lowercased()
    }
    static func url(_ summary: ConversationSummary) -> URL {
        if let origin = fixtureOrigin { return URL(string: origin + "/c/" + summary.id)! }
        return summary.url
    }
}

@MainActor @Observable
final class CEFWorkspace {
    let library: SnapshotLibrary
    var sessions: [CEFSession] = []
    var active: CEFSession?
    var showRecovery = false
    var showStatus = false
    var recoveryID: String?
    var syncState = "idle"
    var selectionMilliseconds: Double = 0
    var cacheHits = 0
    var coldLoads = 0
    var titleChanged: (() -> Void)?
    private var pressure: DispatchSourceMemoryPressure?
    private var closing = false

    init(library: SnapshotLibrary) {
        self.library = library
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler { [weak self] in Task { @MainActor [weak self] in self?.trim() } }
        source.resume(); pressure = source
    }
    func start(url: URL? = nil) async {
        guard active == nil, !closing else { return }
        // Website first: no SQLite query or local transcript UI on the startup path.
        let initial = url ?? URL(string: "https://chatgpt.com/")!
        select(url: initial, identity: CEFIdentity.conversation(initial))
        await library.refresh()
    }
    func open(_ summary: ConversationSummary) { select(url: CEFIdentity.url(summary), identity: summary.id) }
    func openURL(_ url: URL) { select(url: url, identity: CEFIdentity.conversation(url)) }
    private func select(url: URL, identity: String?) {
        guard !closing else { return }
        let began = ContinuousClock.now
        showRecovery = false
        if let identity, let existing = sessions.first(where: { !$0.retired && $0.conversation == identity }) {
            active = existing; sessions.removeAll { $0 === existing }; sessions.append(existing)
            cacheHits += 1; syncState = "cacheHit"
        } else {
            let next = CEFSession(id: NativeProduct.shared.nextKey(), url: url)
            sessions.append(next); active = next; coldLoads += 1; syncState = "coldLoad"
        }
        while sessions.count > 3 { let oldest = sessions.removeFirst(); oldest.retire(library: library) }
        let elapsed = began.duration(to: .now).components
        selectionMilliseconds = Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15
        titleChanged?()
    }
    func receive(_ batch: ObservedConversation, session: CEFSession, browser: Int32) async -> Bool {
        guard !closing, !session.retired, library.enabled, session.browser == browser,
              batch.schema == 1, SnapshotIdentity.valid(batch.documentID),
              batch.conversationID == session.conversation, batch.sequence > 0,
              batch.messages.count <= 500,
              batch.messages.reduce(0, { $0 + $1.body.utf8.count }) <= 2 * 1024 * 1024,
              batch.messages.allSatisfy({ SnapshotIdentity.valid($0.id) && ["assistant", "user"].contains($0.role) && $0.body.utf8.count <= 1024 * 1024 }) else { return false }
        if session.documentID == batch.documentID, batch.sequence <= session.sequence { return false }
        // No await occurs until identity and ordering have been validated.
        let accepted = await library.receive(batch)
        guard accepted, !closing, !session.retired, session.conversation == batch.conversationID else { return false }
        session.observerAvailable = true
        session.documentID = batch.documentID; session.sequence = batch.sequence
        session.pageState = batch.pageState
        if batch.pageState == .readFailure || batch.pageState == .interrupted { session.error = session.error ?? "官方内容读取失败，本机副本仍保留" }
        else if batch.messages.contains(where: { !$0.body.isEmpty && $0.state != .readFailure && !SnapshotIdentity.isErrorText($0.body) }) {
            session.readableConversation = batch.conversationID; session.error = nil
            if active === session { syncState = "officialReadable" }
        }
        titleChanged?(); return true
    }
    var protectionStatus: String {
        [library.enabled ? "本地快照：启用" : "本地快照：暂停",
         active?.observerAvailable == true ? "隔离观察器：已安装" : "隔离观察器：不可用／尚未安装",
         active?.pageState == .unavailable ? "当前页面尚未可靠核对会话与消息身份，正文可能尚未保存；可见回复不等于已受保护。" : "页面状态：\(active?.pageState.rawValue ?? "unavailable")",
         "同步：\(syncState)，缓存 \(sessions.count)/3",
         "当前会话本机回复：\(library.recent.first(where: { $0.id == active?.conversation })?.messageCount ?? 0)",
         active?.error ?? library.warning ?? "未报告读取错误",
         "页面结束不代表服务端持久化完成；用户提问或工具卡片可能未被捕获。"].joined(separator: "\n\n")
    }
    func recover() { recoveryID = active?.conversation ?? library.recent.first?.id; showRecovery = true }
    func trim() {
        let old = sessions.filter { $0 !== active }
        sessions.removeAll { $0 !== active }
        for session in old { session.retire(library: library) }
    }
    func close() async {
        guard !closing else { return }; closing = true
        pressure?.cancel(); pressure = nil
        for session in sessions {
            await session.flush()
            if let id = session.conversation, let store = library.store { try? await store.interrupt(id) }
            session.retire(library: library)
        }
        sessions = []; active = nil
    }
}

struct CEFDeck: NSViewRepresentable {
    let workspace: CEFWorkspace
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ deck: NSView, context: Context) {
        let kept = Set(workspace.sessions.map { ObjectIdentifier($0.host) })
        for child in deck.subviews where !kept.contains(ObjectIdentifier(child)) { child.removeFromSuperview() }
        for session in workspace.sessions {
            if session.host.superview !== deck {
                session.host.frame = deck.bounds; session.host.autoresizingMask = [.width, .height]
                deck.addSubview(session.host); session.attachmentCount += 1
            }
            session.host.isHidden = session !== workspace.active
            // Never create/load a CEF browser during a SwiftUI update call.
            if session.browser == 0 { DispatchQueue.main.async { session.mount(enabled: workspace.library.enabled) } }
        }
    }
}

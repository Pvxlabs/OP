import AppKit
import SwiftUI
import WebKit

private let conversationA = "11111111-1111-4111-8111-111111111111"
private let messageA = "22222222-2222-4222-8222-222222222222"
private let messageB = "33333333-3333-4333-8333-333333333333"
private let sourceID = "44444444-4444-4444-8444-444444444444"
private let completeText = String(repeating: "Synthetic protected response. 中文测试。\n", count: 150)

@MainActor
private final class FixtureHandler: NSObject, WKURLSchemeHandler {
    var requests = 0
    var status = 200
    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        requests += 1
        let conversation = urlSchemeTask.request.url!.lastPathComponent
        let html = """
        <!doctype html><meta charset="utf-8"><title>Reply Protection Synthetic Fixture</title>
        <main><article data-talvt-turn-state="complete"><div data-content-search-unit-key="fallback-turn-0:1:assistant" data-chatgpt-search-message-ids="\(messageA) \(messageA)"><div data-chatgpt-selection-conversation-id="\(conversation)" data-chatgpt-selection-message-id="\(messageA)"><div data-dil-message-id="\(messageA)" class="synthetic-body"><pre>\(completeText)</pre></div></div></div></article></main>
        <span role="status" aria-live="polite">回答已完成</span>
        """
        let data = Data(html.utf8)
        urlSchemeTask.didReceive(HTTPURLResponse(url: urlSchemeTask.request.url!, statusCode: status,
                                               httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "text/html; charset=utf-8"])!)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }
    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}
}

@MainActor
private final class Suite {
    let directory: URL
    var checks: [String] = []
    var metrics: [String: Double] = [:]
    var window: NSWindow?
    init(directory: URL) { self.directory = directory }
    func check(_ condition: Bool, _ name: String) throws {
        guard condition else { throw NSError(domain: "ProtectionTests", code: 1, userInfo: [NSLocalizedDescriptionKey: name]) }
        checks.append(name)
    }
    func wait(_ predicate: @MainActor () async throws -> Bool) async throws {
        for _ in 0..<100 {
            if try await predicate() { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw NSError(domain: "ProtectionTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for observable state"])
    }
    func batch(_ sequence: Int, body: String, state: PageObservation, id: String = messageA,
               conversation: String = conversationA, page: PageObservation = .unverified) -> ObservedConversation {
        ObservedConversation(schema: 1, documentID: sourceID, sequence: sequence, conversationID: conversation,
            pageState: page, messages: [ObservedMessage(id: id, role: "assistant", body: body, state: state,
                evidence: state == .complete ? "explicit-complete" : (state == .pageEnded ? "turn-completed-stable" : nil))])
    }
    func newStore(_ name: String, limits: SnapshotStore.Limits = .init()) throws -> SnapshotStore {
        try SnapshotStore(url: directory.appendingPathComponent(name + ".sqlite"), limits: limits)
    }
    func core() async throws {
        let store = try newStore("core")
        try await store.ingest(batch(1, body: completeText, state: .complete))
        var saved = try await store.messages(in: conversationA)
        try check(saved.count == 1 && saved[0].state == .complete && saved[0].body == completeText, "complete body committed")
        for (sequence, body, state) in [(2, "", PageObservation.unavailable), (3, "无法加载此回复", .readFailure),
                                        (4, "Too many requests", .readFailure)] {
            try await store.ingest(batch(sequence, body: body, state: state, page: .readFailure))
        }
        saved = try await store.messages(in: conversationA)
        try check(saved[0].body == completeText && saved[0].state == .complete && saved[0].lastObservation == .readFailure,
                  "empty placeholder and synthetic 429 preserve complete body")
        try await store.ingest(batch(5, body: completeText, state: .complete))
        saved = try await store.messages(in: conversationA)
        try check(saved.count == 1 && saved[0].lastObservation == .complete, "official recovery reconciles without duplicates")
        try await store.ingest(batch(6, body: "Different complete synthetic response", state: .complete))
        saved = try await store.messages(in: conversationA)
        try check(saved[0].body == completeText && saved[0].hasConflict, "same ID different complete body retains original and conflict")
        try await store.ingest(batch(7, body: "Partial stream", state: .streaming, id: messageB))
        try await store.interrupt(conversationA)
        saved = try await store.messages(in: conversationA)
        try check(saved.first { $0.id == messageB }?.state == .interrupted, "stream interruption remains incomplete")
        try await store.ingest(batch(8, body: "Partial stream recovered and extended", state: .unverified, id: messageB))
        saved = try await store.messages(in: conversationA)
        try check(saved.count == 2 && saved.last?.state == .unverified, "stream recovery extends without declaring completion")
        let bad = ObservedConversation(schema: 1, documentID: sourceID, sequence: 9, conversationID: conversationA,
            pageState: .complete, messages: [ObservedMessage(id: "missing-id", role: "assistant", body: "Skip", state: .complete, evidence: nil)])
        try await store.ingest(bad)
        let unsupportedComplete = ObservedConversation(schema: 1, documentID: sourceID, sequence: 10, conversationID: conversationA,
            pageState: .complete, messages: [ObservedMessage(id: messageB, role: "assistant", body: "Partial stream recovered and extended", state: .complete, evidence: nil)])
        try await store.ingest(unsupportedComplete)
        saved = try await store.messages(in: conversationA)
        try check(saved.count == 2 && saved.last?.state != .complete, "unknown identity and unsupported terminal never become complete")
        try await store.ingest(batch(7, body: "Old event", state: .complete))
        try check(try await store.messages(in: conversationA).first?.body == completeText, "older sequence ignored")

        let isolated = "55555555-5555-4555-8555-555555555555"
        try await store.ingest(batch(11, body: "Another conversation", state: .complete, conversation: isolated))
        try check(try await store.messages(in: isolated).count == 1, "same message ID isolated by conversation")

        let ordering = try newStore("ordering")
        try await ordering.ingest(batch(1, body: "Later message", state: .unverified, id: messageB))
        let history = ObservedConversation(schema: 1, documentID: sourceID, sequence: 2, conversationID: conversationA,
            pageState: .unverified, messages: [ObservedMessage(id: messageA, role: "user", body: "Earlier message", state: .unverified, evidence: nil),
                                              ObservedMessage(id: messageB, role: "assistant", body: "Later message", state: .unverified, evidence: nil)])
        try await ordering.ingest(history)
        try check(try await ordering.messages(in: conversationA).map(\.id) == [messageA, messageB], "history prefix inserted in observed order")
        let prefix = (1...100).map { index in
            ObservedMessage(id: String(format: "%08d-9999-4999-8999-999999999999", index), role: "user",
                            body: "History \(index)", state: .unverified, evidence: nil)
        }
        try await ordering.ingest(ObservedConversation(schema: 1, documentID: sourceID, sequence: 3, conversationID: conversationA,
            pageState: .unverified, messages: prefix + history.messages))
        let orderedHistory = try await ordering.messages(in: conversationA)
        try check(orderedHistory.map(\.id) == (prefix + history.messages).map(\.id), "large history prefix has stable order without fractional collisions")
        let unchanged = try await ordering.ingest(ObservedConversation(schema: 1, documentID: sourceID, sequence: 4,
            conversationID: conversationA, pageState: .unverified, messages: []))
        try check(!unchanged, "unchanged delta causes no content writes")

        let bounded = try newStore("bounded", limits: .init(conversations: 2, messages: 3, bytes: 20000, age: 3600))
        for index in 1...3 {
            let id = String(format: "%08d-1111-4111-8111-111111111111", index)
            try await bounded.ingest(batch(index, body: "Bounded", state: .unverified, conversation: id), now: Date().addingTimeInterval(Double(index)))
        }
        try check(try await bounded.recent().count == 2, "conversation retention bounded")
        let messageBound = try newStore("message-bound", limits: .init(conversations: 20, messages: 2, bytes: 20000, age: 3600))
        for index in 1...3 {
            let id = String(format: "%08d-2222-4222-8222-222222222222", index)
            try await messageBound.ingest(batch(index, body: "Message \(index)", state: .unverified, id: id))
        }
        let boundedMessages = try await messageBound.messages(in: conversationA)
        try check(boundedMessages.count == 2 && boundedMessages.last?.body == "Message 3", "message budget preserves newest replies")
        let bytes = try newStore("bytes", limits: .init(conversations: 20, messages: 3, bytes: 100, age: 3600))
        try await bytes.ingest(batch(1, body: completeText, state: .complete))
        try check(try await bytes.recent().isEmpty, "byte budget evicts whole conversation")
        let age = try newStore("age", limits: .init(conversations: 20, messages: 3, bytes: 20000, age: 1))
        try await age.ingest(batch(1, body: "Old", state: .unverified), now: Date().addingTimeInterval(-10))
        try await age.ingest(batch(2, body: "New", state: .unverified, conversation: isolated))
        try check(try await age.recent().map(\.id) == [isolated], "age retention evicts old conversation")
        try await bounded.clear()
        try check(try await bounded.recent().isEmpty, "snapshot-only clearing")

        let restart = try newStore("restart")
        try await restart.ingest(batch(1, body: completeText, state: .complete))
        try await restart.ingest(batch(2, body: "Stream saved before process exit", state: .streaming, id: messageB))
        try check(true, "restart fixture committed for separate process")
    }

    func webkit() async throws {
        let store = try newStore("webkit")
        let library = SnapshotLibrary(store: store, preferences: nil)
        let handler = FixtureHandler()
        func session() -> BrowserSession {
            let config = WKWebViewConfiguration()
            config.websiteDataStore = .default()
            config.setURLSchemeHandler(handler, forURLScheme: "snapshot-fixture")
            return BrowserSession(configuration: config, loadHome: false, library: library, allowFixtures: true)
        }
        let session = session()
        let view = session.webView
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 720),
                          styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window?.title = "Reply Protection — Synthetic WebKit Tests"
        window?.contentView = view
        window?.makeKeyAndOrderFront(nil)
        let url = URL(string: "snapshot-fixture://local/c/\(conversationA)")!
        session.startOnce(at: url)
        try await wait { try await store.messages(in: conversationA).first?.state == .pageEnded }
        try check(session.observerAvailable && view.configuration.websiteDataStore.isPersistent, "public isolated-world bridge and persistent website store")
        let first = try await store.messages(in: conversationA)[0]
        try check(first.body == completeText.trimmingCharacters(in: .whitespacesAndNewlines), "real WebKit DOM captured full synthetic body")
        _ = try await view.evaluateJavaScript("let f=document.createElement('iframe'); f.src='snapshot-fixture://local/c/99999999-9999-4999-8999-999999999999'; document.body.append(f)")
        try await wait { (try await view.evaluateJavaScript("document.querySelector('iframe').contentDocument?.readyState==='complete'") as? Bool) == true }
        try check(try await store.messages(in: "99999999-9999-4999-8999-999999999999").isEmpty, "subframe fixture is not captured")
        _ = try await view.evaluateJavaScript("document.querySelector('.synthetic-body').textContent='无法加载此回复'; document.querySelector('article').setAttribute('data-talvt-turn-state','in_progress')")
        try await wait { try await store.messages(in: conversationA).first?.lastObservation == .readFailure }
        try check(try await store.messages(in: conversationA).first?.fingerprint == first.fingerprint, "real DOM placeholder cannot overwrite protected body")
        _ = try await view.evaluateJavaScript("document.querySelector('main').innerHTML='<p>Too many requests</p>'")
        try await wait { session.pageState == .readFailure }
        try check(try await store.messages(in: conversationA).first?.body == first.body, "synthetic read failure with no nodes preserves body")
        handler.status = 429
        view.reload()
        try await wait { handler.requests >= 2 && session.navigationFinishes >= 2 }
        try await wait { try await store.messages(in: conversationA).first?.lastObservation == .pageEnded }
        try check(try await store.messages(in: conversationA).count == 1, "real WebKit reload reconciles original ID without duplicates")
        let port = try String(contentsOf: directory.appendingPathComponent("fixture-port"), encoding: .utf8)
        let httpSession = BrowserSession(loadHome: false, library: library)
        httpSession.startOnce(at: URL(string: "http://127.0.0.1:\(port)/c/\(conversationA)")!)
        try await wait { httpSession.lastHTTPStatus == 429 && httpSession.navigationFinishes == 1 }
        let afterHTTPFailure = try await store.messages(in: conversationA)
        try check(httpSession.pageState == .readFailure && afterHTTPFailure.first?.body == first.body,
                  "real loopback HTTP 429 observed by public navigation delegate preserves saved body")
        metrics["observedLoopbackHTTPStatus"] = Double(httpSession.lastHTTPStatus!)
        httpSession.retire()

        // A global completion announcement + explicit in-progress turn cannot complete a stream.
        _ = try await view.evaluateJavaScript("document.querySelector('[data-dil-message-id]').setAttribute('data-dil-message-id','\(messageB)'); document.querySelector('[data-chatgpt-selection-message-id]').removeAttribute('data-chatgpt-selection-message-id'); document.querySelector('[data-chatgpt-search-message-ids]').setAttribute('data-chatgpt-search-message-ids','\(messageB)'); document.querySelector('article').setAttribute('data-talvt-turn-state','in_progress'); document.querySelector('.synthetic-body').textContent='Synthetic unfinished stream'")
        try await wait { try await store.messages(in: conversationA).first { $0.id == messageB }?.state == .streaming }
        try check(try await store.messages(in: conversationA).last?.state == .streaming, "global completion text does not complete in-progress turn")
        _ = try await view.evaluateJavaScript("document.querySelector('.synthetic-body').textContent += ' and extended'")
        try await wait { try await store.messages(in: conversationA).first { $0.id == messageB }?.body == "Synthetic unfinished stream and extended" }
        try check(true, "stream increments persist before secondary selection message ID exists")
        session.retire()
        try await wait { try await store.messages(in: conversationA).first { $0.id == messageB }?.state == .interrupted }
        try check(true, "retiring WebView marks stream interrupted")

        // Same observer in production configuration refuses a fixture origin.
        let denied = try newStore("denied")
        let deniedLibrary = SnapshotLibrary(store: denied, preferences: nil)
        let deniedConfig = WKWebViewConfiguration()
        deniedConfig.setURLSchemeHandler(handler, forURLScheme: "snapshot-fixture")
        let deniedSession = BrowserSession(configuration: deniedConfig, loadHome: false, library: deniedLibrary)
        deniedSession.webView.loadHTMLString("<p>untrusted origin</p>", baseURL: URL(string: "https://example.com/"))
        try await wait { deniedSession.navigationFinishes == 1 }
        let pageBridge = try await deniedSession.webView.evaluateJavaScript("Boolean(window.webkit?.messageHandlers?.localReplySnapshot)") as? Bool
        let deniedRecent = try await denied.recent()
        try check(pageBridge == false && deniedRecent.isEmpty, "bridge absent from page world and untrusted origin ignored")
        deniedSession.retire()

        let poolStore = try newStore("pool")
        let poolLibrary = SnapshotLibrary(store: poolStore, preferences: nil)
        let pool = BrowserWorkspace(library: poolLibrary, factory: {
            let config = WKWebViewConfiguration()
            config.setURLSchemeHandler(handler, forURLScheme: "snapshot-fixture")
            return BrowserSession(configuration: config, loadHome: false, library: poolLibrary, allowFixtures: true)
        }, conversationURL: { URL(string: "snapshot-fixture://local/c/\($0.id)")! })
        let a = ConversationSummary(id: conversationA, updatedAt: Date(), messageCount: 1)
        let b = ConversationSummary(id: "66666666-6666-4666-8666-666666666666", updatedAt: Date(), messageCount: 1)
        let c = ConversationSummary(id: "77777777-7777-4777-8777-777777777777", updatedAt: Date(), messageCount: 1)
        let d = ConversationSummary(id: "88888888-8888-4888-8888-888888888888", updatedAt: Date(), messageCount: 1)
        let coldStart = ContinuousClock.now
        pool.open(a)
        window?.contentView = pool.active.webView
        try await wait { pool.active.navigationFinishes == 1 }
        let cold = coldStart.duration(to: .now).components
        metrics["coldFixtureLoadMs"] = Double(cold.seconds) * 1000 + Double(cold.attoseconds) / 1e15
        let original = pool.active
        pool.open(b)
        window?.contentView = pool.active.webView
        try await wait { pool.active.navigationFinishes == 1 }
        let second = pool.active
        let requestsBefore = handler.requests
        let startsBefore = original.navigationStarts
        var switches: [Double] = []
        for _ in 0..<20 { pool.open(a); pool.open(b); switches.append(pool.switchMilliseconds) }
        pool.open(a)
        window?.contentView = pool.active.webView
        try await Task.sleep(for: .milliseconds(300))
        try check(pool.active === original && handler.requests == requestsBefore && original.navigationStarts == startsBefore,
                  "41 warm selections preserve WebView and trigger zero loads")
        metrics["warmSelectionMedianMs"] = switches.sorted()[switches.count / 2]
        metrics["warmAdditionalRequests"] = Double(handler.requests - requestsBefore)
        let warmStart = ContinuousClock.now
        _ = try await original.webView.callAsyncJavaScript("await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r))); return true", arguments: [:], in: nil, contentWorld: MessageObserver.world)
        let warmFrame = warmStart.duration(to: .now).components
        metrics["warmTwoFrameWaitMs"] = Double(warmFrame.seconds) * 1000 + Double(warmFrame.attoseconds) / 1e15
        let context = WebContent(session: original)
        let hosting = NSHostingView(rootView: context)
        window?.contentView = hosting
        hosting.rootView = WebContent(session: original)
        NSApp.activate(ignoringOtherApps: true)
        try await Task.sleep(for: .milliseconds(300))
        try check(original.navigationStarts == startsBefore, "SwiftUI rebuild and activation add zero loads")
        pool.open(c)
        try await wait { pool.active.navigationFinishes == 1 }
        pool.open(d)
        try await wait { pool.active.navigationFinishes == 1 }
        try check(pool.sessions.count == 3 && !pool.sessions.contains { $0 === second } && pool.sessions.contains { $0 === original }, "LRU holds at most three views and evicts oldest")
        pool.close()
        try check(pool.sessions.isEmpty, "window close releases retained sessions")
        metrics["maxRetainedViewsPerWindow"] = 3
        await library.clear()
        let clearedRecent = try await store.recent()
        try check(!library.enabled && clearedRecent.isEmpty, "clear pauses recapture without touching website data")
        let pausedConfig = WKWebViewConfiguration()
        pausedConfig.setURLSchemeHandler(handler, forURLScheme: "snapshot-fixture")
        let paused = BrowserSession(configuration: pausedConfig, loadHome: false, library: library, allowFixtures: true)
        paused.startOnce(at: url)
        try await wait { paused.navigationFinishes == 1 }
        try check(try await store.recent().isEmpty, "disabled observer does not recapture on load")
        library.enabled = true
        try await wait { try await store.messages(in: conversationA).first?.state == .pageEnded }
        await library.clear()
        try await Task.sleep(for: .milliseconds(300))
        try check(try await store.recent().isEmpty, "clear leaves live page paused and empty")
        library.enabled = true
        try await wait { try await store.messages(in: conversationA).first?.state == .pageEnded }
        try check(true, "explicit re-enable captures unchanged live content again")
        let stoppedID = "abcdefab-1234-4234-8234-123456789012"
        _ = try await paused.webView.evaluateJavaScript("document.querySelector('[data-dil-message-id]').setAttribute('data-dil-message-id','\(stoppedID)'); document.querySelector('[data-chatgpt-selection-message-id]').setAttribute('data-chatgpt-selection-message-id','\(stoppedID)'); document.querySelector('[data-chatgpt-search-message-ids]').setAttribute('data-chatgpt-search-message-ids','\(stoppedID)'); document.querySelector('article').setAttribute('data-talvt-turn-state','in_progress'); document.querySelector('.synthetic-body').textContent='Synthetic user-stopped stream'; let stop=document.createElement('button'); stop.setAttribute('aria-label','停止'); document.body.append(stop)")
        try await wait { try await store.messages(in: conversationA).first { $0.id == stoppedID }?.state == .streaming }
        _ = try await paused.webView.evaluateJavaScript("document.querySelector('button[aria-label=停止]').click(); document.querySelector('article').setAttribute('data-talvt-turn-state','complete')")
        try await wait { try await store.messages(in: conversationA).first { $0.id == stoppedID }?.interruptionReason == "user-stop" }
        try await store.ingest(batch(1, body: "Synthetic user-stopped stream", state: .pageEnded, id: stoppedID))
        let stoppedMessage = try await store.messages(in: conversationA).first { $0.id == stoppedID }
        try check(stoppedMessage?.state == .interrupted, "user stop remains interrupted even when page later reports complete")
        try check(first.state == .pageEnded, "page complete is not an authoritative complete reply")
        paused.retire()
        let startupStore = try newStore("startup")
        try await startupStore.ingest(batch(1, body: "Startup snapshot", state: .complete))
        let startupLibrary = SnapshotLibrary(store: startupStore, preferences: nil)
        func makeWindowWorkspace() -> BrowserWorkspace {
            BrowserWorkspace(library: startupLibrary, factory: {
                let config = WKWebViewConfiguration()
                config.setURLSchemeHandler(handler, forURLScheme: "snapshot-fixture")
                return BrowserSession(configuration: config, loadHome: false, library: startupLibrary, allowFixtures: true)
            }, conversationURL: { URL(string: "snapshot-fixture://local/c/\($0.id)")! },
               homeURL: URL(string: "snapshot-fixture://local/")!)
        }
        let firstWindow = makeWindowWorkspace()
        await firstWindow.start()
        try await wait { firstWindow.active.navigationFinishes == 1 }
        try check(firstWindow.showRecovery && firstWindow.active.matches(conversationA), "first window restores recent local conversation")
        firstWindow.showRecovery = false
        var ownerCreations = 0
        let createOwner: @MainActor () -> BrowserWorkspace = { ownerCreations += 1; return firstWindow }
        let contentHost = NSHostingView(rootView: ContentView(makeWorkspace: createOwner))
        window?.contentView = contentHost
        for _ in 0..<20 { contentHost.rootView = ContentView(makeWorkspace: createOwner) }
        try await Task.sleep(for: .milliseconds(300))
        try check(firstWindow.active.navigationStarts == 1, "full ContentView reconstruction causes zero extra loads")
        try check(ownerCreations == 1, "lazy window owner is created once across View value reconstruction")
        let secondWindow = makeWindowWorkspace()
        await secondWindow.start()
        try await wait { secondWindow.active.navigationFinishes == 1 }
        try check(!secondWindow.showRecovery && secondWindow.active.webView.url?.path == "/", "additional window starts home without reopening recent conversation")
        firstWindow.close()
        secondWindow.close()
        window?.close()
    }

    func restart() async throws {
        let store = try newStore("restart")
        let began = ContinuousClock.now
        let saved = try await store.messages(in: conversationA)
        let elapsed = began.duration(to: .now).components
        metrics["restartLocalReadMs"] = Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15
        try check(saved.count == 2 && saved.first?.body == completeText && saved.first?.state == .complete,
                  "separate process reads durable complete body")
        try check(saved.last?.state == .interrupted, "separate process does not promote old stream")
        let attributes = try FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent("restart.sqlite").path)
        try check((attributes[.posixPermissions] as? Int) == 0o600, "database permissions owner read-write only")
    }

    func preview(website: Bool) async throws {
        let store = try newStore(website ? "website-preview" : "ui-preview")
        let library = SnapshotLibrary(store: store, preferences: nil)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 720),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window?.isReleasedWhenClosed = false
        if website {
            let session = BrowserSession(loadHome: false, library: library)
            previewSession = session
            window?.title = "Reply Protection — Official Synthetic Conversation"
            window?.contentView = session.webView
            session.startOnce(at: URL(string: "https://chatgpt.com/c/6ad53b9b-28fc-83ee-bc67-e0dedda504c4")!)
            Task { @MainActor [weak self, weak session] in
                for _ in 0..<180 {
                    guard let self, let session else { return }
                    guard session.webView.url?.path == "/c/6ad53b9b-28fc-83ee-bc67-e0dedda504c4" else {
                        try? await Task.sleep(for: .seconds(2))
                        continue
                    }
                    if let metadata = try? await session.webView.callAsyncJavaScript("""
                        const messages = Array.from(document.querySelectorAll('[data-dil-message-id],[data-message-id]')).slice(-12);
                        const attributes = n => Object.fromEntries(Array.from(n.attributes).filter(a => ['data-message-author-role','data-turn-role','data-talvt-turn-state','data-testid','data-dil-message-id','data-message-id','data-turn-id','role','aria-label','data-chatgpt-selection-message-id','data-chatgpt-selection-conversation-id','data-content-search-unit-key'].includes(a.name)).map(a=>[a.name,a.value]));
                        const hash = async n => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(n.innerText.trim())))).map(x=>x.toString(16).padStart(2,'0')).join('');
                        return {at:Date.now(),path:location.pathname,ready:document.readyState,
                          login:Array.from(document.querySelectorAll('button')).some(b=>['登录','Log in'].includes(b.innerText.trim())),
                          messages:await Promise.all(messages.map(async n=>({attributes:attributes(n),chars:n.innerText.length,fingerprint:await hash(n),
                            markdown:n.querySelectorAll('.markdown').length,
                            ancestors:Array.from((function*(v){for(let i=0;v&&i<18;i++,v=v.parentElement)yield v;})(n)).map(v=>({tag:v.tagName,attributes:attributes(v),attributeNames:Array.from(v.attributes).map(a=>a.name)}))}))),
                          selections:Array.from(document.querySelectorAll('[data-chatgpt-selection-message-id]')).slice(-20).map(n=>({attributes:attributes(n),chars:n.innerText.length,children:Array.from(n.querySelectorAll('[data-testid]')).map(v=>attributes(v))})),
                          messageTestIDs:Array.from(document.querySelectorAll('[data-testid]')).filter(n=>/message|turn/i.test(n.getAttribute('data-testid'))).map(n=>attributes(n)),
                          units:Array.from(document.querySelectorAll('[data-content-search-unit-key]')).map(n=>({key:n.getAttribute('data-content-search-unit-key'),messageIDs:n.getAttribute('data-chatgpt-search-message-ids'),chars:n.innerText.length,attributeNames:Array.from(n.attributes).map(a=>a.name)})),
                          turns:Array.from(document.querySelectorAll('[data-talvt-turn-state]')).map(n=>({attributes:attributes(n),attributeNames:Array.from(n.attributes).map(a=>a.name),labels:Array.from(n.querySelectorAll('h5,h6')).map(v=>v.innerText).filter(t=>/^(你说|ChatGPT 说|ChatGPT said|You said)/.test(t))}))};
                        """, arguments: [:], in: nil, contentWorld: MessageObserver.world),
                       JSONSerialization.isValidJSONObject(metadata),
                       let data = try? JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys]) {
                        try? data.write(to: self.directory.appendingPathComponent("website-dom-metadata.json"), options: .atomic)
                        if let stream = OutputStream(url: self.directory.appendingPathComponent("website-timeline.jsonl"), append: true) {
                            stream.open()
                            if let line = try? JSONSerialization.data(withJSONObject: metadata) {
                                _ = line.withUnsafeBytes { stream.write($0.bindMemory(to: UInt8.self).baseAddress!, maxLength: line.count) }
                                _ = stream.write([10], maxLength: 1)
                            }
                            stream.close()
                        }
                    }
                    try? await Task.sleep(for: .seconds(2))
                }
            }
        } else {
            try await store.ingest(batch(1, body: "SYNTHETIC LOCAL RECOVERY\n\nThis complete reply survived a simulated read failure.\n\n中文本地恢复视图验证：副本明确标记，不覆盖官方网站。", state: .complete))
            try await store.ingest(batch(2, body: "", state: .readFailure, page: .readFailure))
            await library.refresh()
            window?.title = "Reply Protection — Local Recovery UI"
            window?.contentView = NSHostingView(rootView: RecoveryView(library: library,
                conversationID: .constant(conversationA), openOfficial: { _ in }))
        }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    var previewSession: BrowserSession?

    func writeResult(_ phase: String, failure: Error? = nil) {
        let result: [String: Any] = ["phase": phase, "status": failure == nil ? "PASS" : "FAIL", "checks": checks,
                                    "metrics": metrics, "error": failure?.localizedDescription ?? ""]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: directory.appendingPathComponent(phase + "-results.json"), options: .atomic)
        }
    }
}

@main
struct ProtectionTestMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let menu = NSMenu()
        let item = NSMenuItem()
        let applicationMenu = NSMenu()
        applicationMenu.addItem(withTitle: "Quit Reply Protection Tests", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = applicationMenu
        menu.addItem(item)
        app.mainMenu = menu
        let arguments = CommandLine.arguments
        guard arguments.count == 3 else { exit(2) }
        let phase = arguments[1]
        let suite = Suite(directory: URL(fileURLWithPath: arguments[2], isDirectory: true))
        Task { @MainActor in
            do {
                if phase == "preview" || phase == "website" {
                    try await suite.preview(website: phase == "website")
                    return
                }
                if phase == "core" { try await suite.core(); try await suite.webkit() }
                else { try await suite.restart() }
                suite.writeResult(phase)
                app.terminate(nil)
            } catch { suite.writeResult(phase, failure: error); app.terminate(nil) }
        }
        app.run()
    }
}

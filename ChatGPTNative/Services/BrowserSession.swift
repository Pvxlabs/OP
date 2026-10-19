import SwiftUI
import WebKit
import OSLog

@MainActor
final class BrowserView: WKWebView {
    static var totalAttachments = 0
    static var totalExplicitLoads = 0
    private(set) var attachmentCount = 0
    private(set) var lastAttachedAt = ProcessInfo.processInfo.systemUptime
    private(set) var explicitLoads = 0
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { Self.totalAttachments += 1; attachmentCount += 1; lastAttachedAt = ProcessInfo.processInfo.systemUptime }
    }
    @discardableResult override func load(_ request: URLRequest) -> WKNavigation? {
        explicitLoads += 1
        Self.totalExplicitLoads += 1
        return super.load(request)
    }
    @objc func reloadPage() { reload() }
    @objc func backPage() { goBack() }
    @objc func forwardPage() { goForward() }
    @objc func newChat() { load(URLRequest(url: URL(string: "https://chatgpt.com/")!)) }
    @objc func zoomIn() { pageZoom = min(pageZoom + 0.1, 2) }
    @objc func zoomOut() { pageZoom = max(pageZoom - 0.1, 0.5) }
    @objc func resetZoom() { pageZoom = 1 }
}

@MainActor @Observable
final class BrowserSession: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    let id = UUID()
    let webView: BrowserView
    var error: String?
    var conversationID: String?
    var pageState: PageObservation = .unavailable
    var navigationStarts = 0
    var navigationFinishes = 0
    var lastLoadMilliseconds: Double?
    var lastHTTPStatus: Int?
    var observerAvailable = false
    private(set) var readableConversationID: String?
    var didObserveContent: (() -> Void)?
    private var navigationBegan: ContinuousClock.Instant?
    private var started = false
    private(set) var pendingConversationID: String?
    private var retired = false
    private let library: SnapshotLibrary
    private let observer: MessageObserver?
    private let allowFixtures: Bool
    private var locationObservation: NSKeyValueObservation?
    private var destinations: [WKDownload: (temporary: URL, final: URL)] = [:]
    private let logger = Logger(subsystem: "local.personal.ChatGPTNative", category: "Navigation")

    init(configuration: WKWebViewConfiguration? = nil, loadHome: Bool = true,
         library: SnapshotLibrary = .shared, observeMessages: Bool = true, allowFixtures: Bool = false) {
        self.library = library
        self.allowFixtures = allowFixtures
        let config = configuration ?? WKWebViewConfiguration()
        if configuration == nil { config.websiteDataStore = .default() }
        observer = observeMessages ? MessageObserver(allowFixtures: allowFixtures, enabled: library.enabled) : nil
        if let observer {
            do { try observer.install(on: config.userContentController); observerAvailable = true }
            catch { observerAvailable = false }
        }
        webView = BrowserView(frame: .zero, configuration: config)
        super.init()
        observer?.webView = webView
        observer?.receive = { [weak self] batch in
            guard let self, !self.retired else { return false }
            self.conversationID = batch.conversationID
            self.pageState = batch.pageState
            let saved = await self.library.receive(batch)
            if batch.messages.contains(where: {
                SnapshotIdentity.valid($0.id) && $0.role == "assistant" &&
                !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !SnapshotIdentity.isErrorText($0.body) && $0.state != .readFailure
            }), self.matches(batch.conversationID) {
                self.readableConversationID = batch.conversationID
                self.pendingConversationID = nil
            }
            self.didObserveContent?()
            return saved
        }
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        locationObservation = webView.observe(\.url, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.updateLocation() }
        }
        watchCapturePreference()
        if loadHome { startOnce(at: URL(string: "https://chatgpt.com/")!) }
    }

    func startOnce(at url: URL) {
        guard !started, !retired else { return }
        started = true
        conversationID = SnapshotIdentity.conversation(in: url)
        pendingConversationID = conversationID
        if allowFixtures { pendingConversationID = url.lastPathComponent.lowercased() }
        webView.load(URLRequest(url: url))
    }
    func matches(_ conversation: String) -> Bool {
        if allowFixtures, webView.url?.scheme == "snapshot-fixture" {
            return webView.url?.lastPathComponent.lowercased() == conversation
        }
        return SnapshotIdentity.conversation(in: webView.url) == conversation
    }
    private func updateLocation() {
        let previous = conversationID
        if let official = SnapshotIdentity.conversation(in: webView.url) { conversationID = official }
        else if allowFixtures, let value = webView.url?.lastPathComponent, SnapshotIdentity.valid(value) { conversationID = value.lowercased() }
        else { conversationID = nil }
        if previous != conversationID { library.interrupt(previous); pageState = .unavailable; readableConversationID = nil }
    }
    private func watchCapturePreference() {
        guard !retired, observer != nil else { return }
        withObservationTracking { _ = library.enabled } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.applyCapturePreference()
                self?.watchCapturePreference()
            }
        }
    }
    private func applyCapturePreference() {
        guard !retired, observer != nil else { return }
        webView.callAsyncJavaScript("if (typeof __nativeSnapshotSetEnabled === 'function') __nativeSnapshotSetEnabled(enabled)",
            arguments: ["enabled": library.enabled], in: nil, in: MessageObserver.world, completionHandler: { _ in })
    }
    func retire() {
        guard !retired else { return }
        retired = true
        library.interrupt(conversationID)
        webView.stopLoading()
        if observer != nil {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: MessageObserver.handlerName,
                                                                                  contentWorld: MessageObserver.world)
        }
        observer?.receive = nil
        didObserveContent = nil
        locationObservation = nil
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        error = nil
        library.interrupt(conversationID)
        pageState = .unavailable
        readableConversationID = nil
        navigationStarts += 1
        navigationBegan = .now
        logger.info("navigation started")
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationFinishes += 1
        if let navigationBegan {
            let duration = navigationBegan.duration(to: .now).components
            lastLoadMilliseconds = Double(duration.seconds) * 1000 + Double(duration.attoseconds) / 1e15
        }
        updateLocation()
        // The script was injected at document end; apply any preference change during navigation.
        applyCapturePreference()
        logger.info("navigation finished host=\(webView.url?.host ?? "unknown", privacy: .public)")
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { record(error) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { record(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        library.interrupt(conversationID)
        pageState = .interrupted
        error = "Web content process stopped. Reload to continue."
        didObserveContent?()
        logger.error("web content process terminated")
    }
    private func record(_ failure: Error) {
        let code = (failure as NSError).code
        guard code != NSURLErrorCancelled else { return }
        error = failure.localizedDescription
        pageState = .readFailure
        didObserveContent?()
        logger.error("operation failed code=\(code)")
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        logger.info("navigation policy scheme=\(navigationAction.request.url?.scheme ?? "none", privacy: .public) download=\(navigationAction.shouldPerformDownload)")
        if navigationAction.shouldPerformDownload { decisionHandler(.download); return }
        if let url = navigationAction.request.url, let scheme = url.scheme,
           !["https", "http", "about", "blob", "data"].contains(scheme),
           !(allowFixtures && scheme == "snapshot-fixture") {
            if navigationAction.navigationType == .linkActivated { NSWorkspace.shared.open(url) }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void) {
        logger.info("response policy mime=\(navigationResponse.response.mimeType ?? "none", privacy: .public)")
        if navigationResponse.isForMainFrame, let response = navigationResponse.response as? HTTPURLResponse {
            lastHTTPStatus = response.statusCode
            if response.statusCode >= 400 {
                pageState = .readFailure
                error = "官方网页读取失败（HTTP \(response.statusCode)）。可查看本地副本。"
                didObserveContent?()
            }
        }
        decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
    }
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping @MainActor @Sendable (URL?) -> Void) {
        logger.info("download destination requested")
        let panel = NSSavePanel()
        panel.nameFieldStringValue = (suggestedFilename as NSString).lastPathComponent
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        guard let window = webView.window else { completionHandler(nil); return }
        panel.beginSheetModal(for: window) { result in
            guard result == .OK, let destination = panel.url else { completionHandler(nil); return }
            // Download beside the destination and replace only after success,
            // preserving an existing file if the transfer fails or is cancelled.
            let temporary = destination.deletingLastPathComponent()
                .appendingPathComponent(".chatgpt-\(UUID().uuidString).download")
            self.destinations[download] = (temporary, destination)
            completionHandler(temporary)
        }
    }
    func downloadDidFinish(_ download: WKDownload) {
        guard let destination = destinations.removeValue(forKey: download) else { return }
        do {
            if FileManager.default.fileExists(atPath: destination.final.path) {
                _ = try FileManager.default.replaceItemAt(destination.final, withItemAt: destination.temporary)
            } else {
                try FileManager.default.moveItem(at: destination.temporary, to: destination.final)
            }
            logger.info("download finished")
            Notifications.downloadFinished()
        } catch {
            record(error)
            try? FileManager.default.removeItem(at: destination.temporary)
        }
    }
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        if let destination = destinations.removeValue(forKey: download) {
            try? FileManager.default.removeItem(at: destination.temporary)
        }
        record(error)
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = true
        guard let window = webView.window else { completionHandler(nil); return }
        panel.beginSheetModal(for: window) { result in
            completionHandler(result == .OK ? panel.urls : nil)
        }
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        logger.info("web popup requested")
        return PopupWindows.shared.open(configuration: configuration)
    }
    func webViewDidClose(_ webView: WKWebView) { webView.window?.performClose(nil) }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable () -> Void) {
        guard let window = webView.window else { completionHandler(); return }
        let alert = dialog(message, host: frame.securityOrigin.host)
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window) { _ in completionHandler() }
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable (Bool) -> Void) {
        guard let window = webView.window else { completionHandler(false); return }
        let alert = dialog(message, host: frame.securityOrigin.host)
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { completionHandler($0 == .alertFirstButtonReturn) }
    }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable (String?) -> Void) {
        guard let window = webView.window else { completionHandler(nil); return }
        let alert = dialog(prompt, host: frame.securityOrigin.host)
        let field = NSTextField(string: defaultText ?? "")
        field.frame.size = NSSize(width: 300, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { completionHandler($0 == .alertFirstButtonReturn ? field.stringValue : nil) }
    }
    private func dialog(_ message: String, host: String) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = host
        alert.informativeText = message
        return alert
    }
}

struct WebContent: NSViewRepresentable {
    let session: BrowserSession
    func makeNSView(context: Context) -> WKWebView { session.webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

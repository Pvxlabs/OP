import SwiftUI
import WebKit
import OSLog

@MainActor
final class BrowserView: WKWebView {
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
    let webView: BrowserView
    var error: String?
    private var destinations: [WKDownload: (temporary: URL, final: URL)] = [:]
    private let logger = Logger(subsystem: "local.personal.ChatGPTNative", category: "Navigation")

    init(configuration: WKWebViewConfiguration? = nil, loadHome: Bool = true) {
        let config = configuration ?? WKWebViewConfiguration()
        if configuration == nil { config.websiteDataStore = .default() }
        webView = BrowserView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        if loadHome { webView.newChat() }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        error = nil
        logger.info("navigation started")
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        logger.info("navigation finished host=\(webView.url?.host ?? "unknown", privacy: .public)")
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { record(error) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { record(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        error = "Web content process stopped. Reload to continue."
        logger.error("web content process terminated")
    }
    private func record(_ failure: Error) {
        let code = (failure as NSError).code
        guard code != NSURLErrorCancelled else { return }
        error = failure.localizedDescription
        logger.error("operation failed code=\(code)")
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        logger.info("navigation policy scheme=\(navigationAction.request.url?.scheme ?? "none", privacy: .public) download=\(navigationAction.shouldPerformDownload)")
        if navigationAction.shouldPerformDownload { decisionHandler(.download); return }
        if let url = navigationAction.request.url, let scheme = url.scheme,
           !["https", "http", "about", "blob", "data"].contains(scheme) {
            if navigationAction.navigationType == .linkActivated { NSWorkspace.shared.open(url) }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void) {
        logger.info("response policy mime=\(navigationResponse.response.mimeType ?? "none", privacy: .public)")
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

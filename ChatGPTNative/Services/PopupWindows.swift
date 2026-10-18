import AppKit
import WebKit

/// Owns web-created windows until close; uses the exact configuration supplied
/// by WebKit so OAuth opener relationships and the persistent store survive.
@MainActor
final class PopupWindows: NSObject, NSWindowDelegate {
    static let shared = PopupWindows()
    private var sessions: [NSWindow: BrowserSession] = [:]

    func open(configuration: WKWebViewConfiguration) -> WKWebView {
        let session = BrowserSession(configuration: configuration, loadHome: false)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 760),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "ChatGPT Native — Web Window"
        window.isReleasedWhenClosed = false
        window.contentView = session.webView
        window.delegate = self
        sessions[window] = session
        window.center()
        window.makeKeyAndOrderFront(nil)
        return session.webView
    }
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow { sessions.removeValue(forKey: window) }
    }
}

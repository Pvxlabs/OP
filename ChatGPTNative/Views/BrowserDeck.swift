import SwiftUI
import WebKit

/// One stable native container per window. Inactive cached web views stay mounted
/// but hidden; LRU eviction removes them rather than retaining unbounded layers.
struct BrowserDeck: NSViewRepresentable {
    let workspace: BrowserWorkspace
    func makeNSView(context: Context) -> DeckView { DeckView() }
    func updateNSView(_ view: DeckView, context: Context) {
        view.show(workspace.sessions, active: workspace.active)
    }

    final class DeckView: NSView {
        private var selected: UUID?
        override var isFlipped: Bool { true }
        func show(_ sessions: [BrowserSession], active: BrowserSession) {
            let retained = Set(sessions.map { ObjectIdentifier($0.webView) })
            for child in subviews where !retained.contains(ObjectIdentifier(child)) { child.removeFromSuperview() }
            for session in sessions {
                let web = session.webView
                if web.superview !== self {
                    web.removeFromSuperview()
                    web.frame = bounds
                    web.autoresizingMask = [.width, .height]
                    addSubview(web)
                }
                web.isHidden = session !== active
            }
            if selected != active.id {
                selected = active.id
                if window?.isKeyWindow == true { window?.makeFirstResponder(active.webView) }
            }
        }
    }
}

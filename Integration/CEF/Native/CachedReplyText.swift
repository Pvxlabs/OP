import SwiftUI
import AppKit

// Identical recovery text view to the WebKit baseline; no web injection.
/// Use the AppKit text system for long, selectable cached transcripts. This avoids
/// SwiftUI SelectionOverlay layout invalidation loops inside the recovery overlay.
struct CachedReplyText: NSViewRepresentable {
    let text: String
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let content = scroll.documentView as! NSTextView
        content.isEditable = false
        content.isSelectable = true
        content.isRichText = false
        content.isVerticallyResizable = true
        content.isHorizontallyResizable = false
        content.autoresizingMask = [.width]
        content.textContainer?.widthTracksTextView = true
        content.font = .systemFont(ofSize: 14)
        content.textContainerInset = NSSize(width: 10, height: 12)
        content.minSize = .zero
        content.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        scroll.documentView = content
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let content = scroll.documentView as? NSTextView, content.string != text else { return }
        content.string = text
        content.scrollToBeginningOfDocument(nil)
    }
}

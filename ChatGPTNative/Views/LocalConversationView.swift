import SwiftUI

/// A native presentation only: never modifies the website or sends saved text.
struct LocalConversationView: View {
    let workspace: BrowserWorkspace
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("本地回复副本", systemImage: "internaldrive").font(.headline)
                if let id = workspace.localConversation { Text("会话 …" + id.suffix(8)).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Button("查看官方网页") { workspace.revealOfficial() }
            }
            Text(workspace.syncState == "loadFailed" ? "官方内容暂不可读，以下保留本机副本。可打开网页重试或完成安全验证。" : "正在后台载入此会话的官方内容；当前仅显示本机已保存的回复。")
                .font(.callout).foregroundStyle(.secondary)
            Text("可能不含提问、附件或完整历史，不代表官方当前分支，也不证明生成完整。")
                .font(.caption).foregroundStyle(.secondary)
            if let error = workspace.active.error { Text(error).font(.callout).foregroundStyle(.orange) }
            if let warning = workspace.library.warning { Text(warning).foregroundStyle(.red) }
            if workspace.localLoading { ProgressView("读取本地副本…") }
            else if workspace.localMessages.isEmpty {
                Text("此会话尚无可读取的本地回复，正在等待官方网页。")
            }
            CachedReplyText(text: workspace.localMessages.map { message in
                message.state.label + "\n\n" + message.body +
                    (message.hasConflict ? "\n\n此消息存在不同文本，可在本地副本菜单中查看差异。" : "")
            }.joined(separator: "\n\n────────────────────\n\n"))
        }
        .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background)
        .onChange(of: workspace.localLoading, initial: true) { _, loading in
            if !loading { workspace.metrics.record("localViewAppeared") }
        }
    }
}


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

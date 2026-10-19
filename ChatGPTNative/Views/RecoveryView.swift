import SwiftUI

struct RecoveryView: View {
    let library: SnapshotLibrary
    @Binding var conversationID: String?
    let openOfficial: (ConversationSummary) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [SavedMessage] = []
    @State private var loading = true
    @State private var confirmClear = false
    @State private var showAlternatives = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("本地回复副本", systemImage: "internaldrive").font(.title2)
                Spacer()
                Button("关闭") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text("仅显示本机已捕获的回复文本，可能不含提问或工具内容，不代表官方当前分支。完成标签来自页面观察，不证明服务端已持久保存。")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Picker("最近会话", selection: $conversationID) {
                    Text("选择会话").tag(String?.none)
                    ForEach(library.recent) { item in Text(item.label).tag(Optional(item.id)) }
                }
                Button("打开官方会话") {
                    if let item = library.recent.first(where: { $0.id == conversationID }) { openOfficial(item); dismiss() }
                }.disabled(conversationID == nil)
            }
            if let warning = library.warning { Text(warning).foregroundStyle(.red) }
            if messages.contains(where: \.hasConflict) {
                Toggle("显示同一消息的不同文本", isOn: $showAlternatives).toggleStyle(.checkbox)
            }
            if loading { ProgressView() }
            else if messages.isEmpty { Text("没有可读取的本地快照。无法识别消息身份时不会编造副本。") }
            CachedReplyText(text: Self.transcript(messages, showAlternatives: showAlternatives))
            HStack {
                Toggle("保存本地快照", isOn: Binding(get: { library.enabled }, set: { library.enabled = $0 }))
                Spacer()
                Button("清除本地快照…", role: .destructive) { confirmClear = true }
            }
            Text("保留最近 30 天，最多 200 个会话／64 MiB、每会话最近 500 条；容量超限淘汰最旧会话。清除只影响副本，并暂停采集；网站登录不受影响。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20).frame(minWidth: 700, idealWidth: 800, minHeight: 500, idealHeight: 650)
        .task(id: "\(conversationID ?? "")-\(library.conversationRevisions[conversationID ?? "", default: 0])-\(library.clearEpoch)") {
            loading = true
            let requestedID = conversationID
            let loaded = if let requestedID { await library.messages(requestedID) } else { [SavedMessage]() }
            guard !Task.isCancelled, conversationID == requestedID else { return }
            messages = loaded
            loading = false
        }
        .alert("清除所有本地快照？", isPresented: $confirmClear) {
            Button("取消", role: .cancel) {}
            Button("清除并暂停采集", role: .destructive) { Task { await library.clear(); conversationID = nil } }
        } message: { Text("无法从本机撤销。不会清除网站数据或退出登录。") }
    }

    static func transcript(_ messages: [SavedMessage], showAlternatives: Bool) -> String {
        messages.map { message in
            var parts = [message.role == "assistant" ? "ChatGPT · 本地副本" : "用户 · 本地副本",
                         message.state.label + " · " + message.updatedAt.formatted(date: .omitted, time: .shortened)]
            if message.interruptionReason == "user-stop" {
                parts.append("观察到用户停止生成；这份副本的完整性未确认。")
            } else if message.lastObservation == .readFailure || message.lastObservation == .interrupted {
                parts.append("最近的官方读取失败或采集中断；保留以下已保存正文。")
            }
            parts.append(message.body)
            if let alternative = message.alternativeBody {
                parts.append("同一消息观察到不同文本，原副本已保留。")
                if showAlternatives { parts.append("不同文本：\n" + alternative) }
            }
            return parts.joined(separator: "\n\n")
        }.joined(separator: "\n\n────────────────────\n\n")
    }

}

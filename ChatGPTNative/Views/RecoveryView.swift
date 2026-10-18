import SwiftUI

struct RecoveryView: View {
    let library: SnapshotLibrary
    @Binding var conversationID: String?
    let openOfficial: (ConversationSummary) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [SavedMessage] = []
    @State private var loading = true
    @State private var confirmClear = false

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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if loading { ProgressView() }
                    else if messages.isEmpty { Text("没有可读取的本地快照。无法识别消息身份时不会编造副本。") }
                    ForEach(messages) { message in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(message.role == "assistant" ? "ChatGPT · 本地副本" : "用户 · 本地副本").bold()
                                Text(message.state.label).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text(message.updatedAt, style: .time).font(.caption)
                            }
                            if message.interruptionReason == "user-stop" {
                                Text("观察到用户停止生成；这份副本的完整性未确认。")
                                    .font(.caption).foregroundStyle(.orange)
                            } else if message.lastObservation == .readFailure || message.lastObservation == .interrupted {
                                Text("最近的官方读取失败或采集中断；保留以下已保存正文。")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                            Text(message.body).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                            if let alternative = message.alternativeBody {
                                DisclosureGroup("同一消息观察到不同文本，原副本已保留") {
                                    Text(alternative).textSelection(.enabled)
                                }.font(.callout)
                            }
                            Divider()
                        }
                    }
                }.padding(4)
            }
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
}

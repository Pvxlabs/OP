import SwiftUI

struct ClinxInboxView: View {
    @Bindable var inbox: ClinxInbox
    let conversation: String?
    let conversationTitle: String?
    let openConversation: (String) -> Void
    @State private var endpoint = ""
    @State private var token = ""
    @State private var taskRef = ""
    @State private var executionRef = ""
    @State private var automatic = true
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("CLINX 任务收件箱").font(.title2.bold())
                Spacer()
                Button("收取结果") { Task { await inbox.refresh(identifyConversation: conversation) } }.disabled(inbox.refreshing)
            }
            Text("任务结束后，将结果摘要作为后续消息发到绑定的普通 ChatGPT 原对话。OP 需保持运行并登录；草稿、生成中或发送结果不明时暂停投递。")
                .font(.callout).foregroundStyle(.secondary)
            Toggle("自动识别本对话新出现的 CLINX 任务", isOn: $inbox.identifier.enabled)
            Text(inbox.identifier.status).font(.callout).foregroundStyle(.secondary)
            GroupBox("Observer 连接") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("https://Observer 地址", text: $endpoint).textFieldStyle(.roundedBorder)
                        SecureField("只读 token（保存在钥匙串）", text: $token).textFieldStyle(.roundedBorder)
                        Button("连接") {
                            let credential = token; token = ""
                            Task { await inbox.configure(endpoint: endpoint, monitor: false, token: credential) }
                        }.disabled(inbox.refreshing)
                    }
                    HStack {
                        Button("使用 CLINX Monitor 连接") {
                            Task { await inbox.configure(endpoint: "", monitor: true, token: "") }
                        }.disabled(inbox.refreshing || ClinxCredentials.monitorEndpoint.isEmpty)
                        Text(inbox.connectionStatus).font(.caption).textSelection(.enabled)
                    }
                    if !inbox.effectiveEndpoint.isEmpty {
                        Text("当前：\(inbox.effectiveEndpoint)\(inbox.useMonitor ? " · CLINX Monitor 凭据" : "")")
                            .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }.padding(6)
            }
            GroupBox("原对话") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(conversation != nil ? (conversationTitle ?? "当前普通 ChatGPT 对话") : "请先在 OP 打开原 ChatGPT 会话。")
                        .font(.caption).textSelection(.enabled)
                    Text("ChatGPT 自动识别任务，核验后自动收取。无需配对或填写任务编号。")
                        .font(.callout).foregroundStyle(.secondary)
                    DisclosureGroup("高级：手动补充绑定") {
                    Text(conversation ?? "尚未识别原对话").font(.caption.monospaced())
                    HStack {
                        TextField("task_ref", text: $taskRef).textFieldStyle(.roundedBorder)
                        TextField("execution_ref", text: $executionRef).textFieldStyle(.roundedBorder)
                        Button("绑定") { bind() }.disabled(conversation == nil || inbox.refreshing)
                    }
                    HStack {
                        Toggle("结果就绪后自动回传", isOn: $automatic)
                        Spacer()
                        Button("读取最近任务") { Task { await inbox.loadRecent() } }.disabled(inbox.refreshing)
                        Menu("选择最近任务") {
                            ForEach(inbox.recent) { task in
                                Button((task.title ?? task.taskRef) + " · " + (task.executionRef?.suffix(8) ?? "无执行")) {
                                    taskRef = task.taskRef; executionRef = task.executionRef ?? ""
                                }
                            }
                        }.disabled(inbox.recent.isEmpty)
                    }
                    Text("每次执行只绑定一个原对话；只回传当前执行的脱敏摘要，不代表完整 Codex 报告。")
                        .font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(6)
            }
            if let issue = inbox.persistenceError ?? error { Text(issue).foregroundStyle(.red).textSelection(.enabled) }
            List(inbox.receipts) { receipt in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(receipt.title).font(.headline).lineLimit(1)
                        Spacer()
                        Text(receipt.state.label).font(.callout)
                    }
                    Text(receipt.executionRef).font(.caption.monospaced()).textSelection(.enabled)
                    Text(receipt.detail).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                    HStack {
                        Button("打开原对话") { openConversation(receipt.conversation) }
                        if [.watching, .ready, .paused].contains(receipt.state) {
                            Button(receipt.state == .paused ? "恢复" : "暂停") { inbox.pause(receipt.id) }
                            if !receipt.automatic { Button("启用自动回传") { inbox.enable(receipt.id) } }
                        }
                        if [.sent, .uncertain].contains(receipt.state) {
                            Button("只读核对回执") { Task { await inbox.deliver(receipt.id) } }
                        }
                        if let checked = receipt.lastChecked { Text(checked, style: .time).font(.caption).foregroundStyle(.secondary) }
                    }.buttonStyle(.borderless)
                }.padding(.vertical, 7)
            }.overlay { if inbox.receipts.isEmpty { Text("尚无绑定任务").foregroundStyle(.secondary) } }
        }
        .padding(20).frame(minWidth: 800, minHeight: 680)
        .onAppear { endpoint = inbox.endpoint }
    }
    private func bind() {
        do {
            try inbox.bind(task: taskRef.trimmingCharacters(in: .whitespacesAndNewlines),
                           execution: executionRef.trimmingCharacters(in: .whitespacesAndNewlines),
                           conversation: conversation ?? "", automatic: automatic)
            error = nil
            Task { await inbox.refresh() }
        } catch { self.error = error.localizedDescription }
    }
}

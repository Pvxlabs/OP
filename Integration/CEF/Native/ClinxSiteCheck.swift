import Foundation

// Explicit, bounded live-site acceptance only. It uses a caller-selected test
// conversation and synthetic text; it never reads or forwards a real task result.
@MainActor enum ClinxSiteCheck {
    static func run(product: NativeProduct, conversation: String, evidence: URL) async {
        let marker = "[OP-CLINX:\(UUID().uuidString)]"
        let message = """
        CLINX 回传联通测试 \(marker)
        这是一条 OP 验收用合成回执，不代表任何真实 Codex 任务。
        合成执行状态：COMPLETED；合成验证：仅测试原对话回传与响应。
        请只回复“OP_CLINX_DELIVERY_ACK”，不要调用工具或执行任务。
        """
        var report = ClinxDeliveryReport(status: "waiting", reason: "等待原测试对话身份可核验。")
        var session: CEFSession?
        for _ in 0..<150 {
            if let candidate = product.windows.last?.workspace.active,
               candidate.conversation == conversation, candidate.readableConversation == conversation,
               candidate.browser > 0, !candidate.loading, candidate.error == nil { session = candidate; break }
            try? await Task.sleep(for: .milliseconds(200))
        }
        if let session {
            report = await session.deliverClinx(conversation: conversation, message: message, marker: marker, verify: false)
            // A waiting/uncertain result never triggers another write attempt.
            if report.status == "sent" {
                for _ in 0..<10 {
                    try? await Task.sleep(for: .seconds(2))
                    report = await session.deliverClinx(conversation: conversation, message: message, marker: marker, verify: true)
                    if report.status == "responding" { break }
                }
            }
        }
        let object = ["status": report.status, "reason": report.reason, "conversation": conversation,
                      "marker": marker, "scope": "SYNTHETIC_RESULT_TO_REAL_ORDINARY_CHATGPT_CONVERSATION"]
        do {
            try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
                .write(to: evidence.appendingPathComponent("site-check.json"), options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: evidence.appendingPathComponent("site-check.json").path)
        } catch { product.clinxInbox.connectionStatus = "网页验收证据无法保存。" }
    }
}

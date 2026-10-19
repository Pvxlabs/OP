import Foundation

@MainActor extension CEFIntegrationTests {
    func runClinxModels() async throws -> ClinxReceipt {
        let client = try ClinxObserver(endpoint: CEFIdentity.fixtureOrigin!, fixture: true)
        try await client.health()
        let recent = try await client.recent()
        let task = try await client.task("task_synthetic")
        try check(recent.count == 1 && task.readOnly && task.finalResult?.status == "BLOCKED", "CLINX existing Observer health/list/detail contracts read over real HTTP")
        let conversation = "88888888-8888-4888-8888-888888888888"
        var receipt = ClinxReceipt(id: UUID(), taskRef: task.taskRef, executionRef: "exec_synthetic", conversation: conversation,
                                  endpoint: "https://example.invalid", created: Date(), title: "Fixture", automatic: true)
        try receipt.receive(task)
        try check(receipt.state == .ready && receipt.message!.contains("BLOCKED") && receipt.message!.contains("非 Codex 完整报告"),
                  "terminal BLOCKED result is preserved as a labeled redacted summary, never promoted to PASS")
        var wrong = receipt; wrong.state = .watching
        let mismatch = ClinxTask(schemaVersion: "1", taskRef: task.taskRef, executionRef: "exec_successor", title: task.title,
                                state: "COMPLETED", executionState: "COMPLETED", codexRunning: false,
                                mutationBoundary: task.mutationBoundary, finalResult: task.finalResult)
        do { try wrong.receive(mismatch); try check(false, "successor must reject") } catch is ClinxError { checks.append("successor execution cannot replace the bound result") }
        let running = ClinxTask(schemaVersion: "1", taskRef: task.taskRef, executionRef: task.executionRef, title: task.title,
                               state: "CODEX_RUNNING", executionState: "CODEX_RUNNING", codexRunning: true,
                               mutationBoundary: task.mutationBoundary, finalResult: task.finalResult)
        var pending = receipt; pending.state = .watching; pending.message = nil; try pending.receive(running)
        try check(pending.state == .watching && pending.message == nil, "running execution with an old result cannot queue a follow-up")
        let noResult = ClinxTask(schemaVersion: "1", taskRef: task.taskRef, executionRef: task.executionRef, title: task.title,
                                state: "FAILED", executionState: "FAILED", codexRunning: false,
                                mutationBoundary: task.mutationBoundary, finalResult: nil)
        try pending.receive(noResult)
        try check(pending.state == .watching && pending.message == nil, "terminal status without persisted result never fabricates a report")
        let inboxFile = root.appendingPathComponent("clinx-inbox.json")
        let inbox = ClinxInbox(file: inboxFile, defaults: nil); inbox.endpoint = "https://example.invalid"
        try inbox.bind(task: task.taskRef, execution: "exec_synthetic", conversation: conversation, automatic: true)
        do { try inbox.bind(task: task.taskRef, execution: "exec_synthetic", conversation: a, automatic: true); try check(false, "duplicate bind must reject") }
        catch is ClinxError { checks.append("one execution cannot be bound twice or silently rebound to another chat") }
        try check(ClinxInbox(file: inboxFile, defaults: nil).receipts.count == 1, "CLINX binding survives a store reload")
        inbox.pause(inbox.receipts[0].id)
        try check(inbox.receipts[0].state == .paused, "pause persists before further result processing")
        inbox.pause(inbox.receipts[0].id)
        try check(inbox.receipts[0].state == .watching, "resume preserves the original execution binding")
        var interrupted = receipt; interrupted.state = .sending
        try JSONEncoder().encode([interrupted]).write(to: inboxFile, options: .atomic)
        let restored = ClinxInbox(file: inboxFile, defaults: nil)
        try check(restored.receipts.first?.state == .uncertain && restored.receipts.first?.message == receipt.message,
                  "interrupted send restores as uncertain with frozen content and cannot automatically resend")
        let corruptFile = root.appendingPathComponent("corrupt-inbox.json"); try Data("invalid".utf8).write(to: corruptFile)
        try check(ClinxInbox(file: corruptFile, defaults: nil).persistenceError != nil, "corrupt inbox blocks writes instead of starting an empty delivery ledger")
        let failedStore = ClinxInbox(file: corruptFile.appendingPathComponent("inbox.json"), defaults: nil)
        failedStore.endpoint = "https://example.invalid"
        do { try failedStore.bind(task: task.taskRef, execution: "exec_writefailure", conversation: conversation, automatic: true) }
        catch { }
        try check(failedStore.persistenceError != nil, "failed durable write disables all automatic browser delivery")
        return receipt
    }
    func runClinx(receipt: ClinxReceipt) async throws {
        let conversation = receipt.conversation
        product.openWindow(url: CEFIdentity.url(summary(conversation)))
        let scene = product.windows.last!
        try await wait("CLINX fixture conversation") { scene.workspace.active?.readableConversation == conversation }
        let session = scene.workspace.active!
        func control(_ action: Int32) async throws {
            op_cef_test(session.browser, action); try await Task.sleep(for: .milliseconds(150))
        }
        func delivery(_ verify: Bool = false, chat: String? = nil, text: String? = nil) async -> ClinxDeliveryReport {
            await session.deliverClinx(conversation: chat ?? conversation, message: text ?? receipt.message!, marker: receipt.marker, verify: verify)
        }
        let wrongChat = await delivery(chat: a)
        try check(wrongChat.status == "waiting", "CEF delivery rejects a different original conversation")
        try await control(10)
        let draft = await delivery()
        try check(draft.status == "waiting" && draft.reason.contains("草稿"), "existing draft blocks delivery without replacement")
        try await control(11); try await control(12)
        let busy = await delivery()
        try check(busy.status == "waiting" && busy.reason.contains("生成"), "generating response blocks automatic delivery")
        try await control(13); try await control(14)
        let modal = await delivery()
        try check(modal.status == "waiting" && modal.reason.contains("对话框"), "visible modal blocks delivery")
        try await control(15); try await control(16)
        let attachment = await delivery()
        try check(attachment.status == "waiting" && attachment.reason.contains("附件"), "attachment blocks delivery")
        try await control(17)
        let sent = await delivery()
        try check(["sent", "responding"].contains(sent.status), "real CEF composer receives result and matching user bubble is verified")
        let response = await delivery(true)
        try check(response.status == "responding", "assistant response is observed after the exact result receipt")
        let duplicate = await delivery()
        try check(duplicate.status == "responding", "same receipt is read back without a second send")
        scene.reload(); try await wait("CLINX receipt reload") { !session.loading && session.readableConversation == conversation }
        let afterReload = await delivery(true)
        try check(afterReload.status == "responding", "receipt remains verifiable after real browser reload")
        try await control(18)
        let failed = await delivery(text: receipt.message! + "\nAnother bounded test")
        // The same marker with different content is refused before touching the editor.
        try check(failed.status == "uncertain", "conflicting receipt marker never submits changed content")
        try await control(19)
        let pipeline = ClinxInbox(file: root.appendingPathComponent("clinx-pipeline.json"), defaults: nil, fixture: true)
        pipeline.endpoint = CEFIdentity.fixtureOrigin!
        try pipeline.bind(task: "task_synthetic", execution: "exec_synthetic", conversation: conversation, automatic: true)
        await pipeline.refresh()
        try check([.sent, .responding].contains(pipeline.receipts.first!.state),
                  "full Observer HTTP to durable inbox to original CEF chat pipeline verifies submission")
        await pipeline.refresh()
        try check(pipeline.receipts.first?.state == .responding,
                  "full pipeline separately observes the assistant response without resubmission")
        try check(ClinxInbox(file: root.appendingPathComponent("clinx-pipeline.json"), defaults: nil).receipts.first?.state == .responding,
                  "verified result delivery and response state survive inbox reload")
        try await control(20)
        let unknownMarker = "[OP-CLINX:\(UUID().uuidString)]"
        let unknownText = "Synthetic uncertain delivery \(unknownMarker)"
        let unknown = await session.deliverClinx(conversation: conversation, message: unknownText, marker: unknownMarker, verify: false)
        try check(unknown.status == "uncertain", "click without a matching user bubble remains uncertain")
        let verifyUnknown = await session.deliverClinx(conversation: conversation, message: unknownText, marker: unknownMarker, verify: true)
        try check(verifyUnknown.status == "uncertain", "uncertain receipt verification never sends an absent message")
        await scene.workspace.close()
    }
    func runClinxIdentification() async throws {
        let variants: [(Int32, String)] = [(21,"positive"),(22,"mismatch"),(23,"history"),(24,"quote"),(25,"nonce"),(26,"multiple")]
        for (action, name) in variants {
            let conversation = UUID().uuidString.lowercased()
            product.openWindow(url: CEFIdentity.url(summary(conversation)))
            let scene = product.windows.last!
            try await wait("identification source \(name)") { scene.workspace.active?.readableConversation == conversation }
            let session = scene.workspace.active!
            let directory = root.appendingPathComponent("identify-" + name)
            let file = directory.appendingPathComponent("inbox.json")
            let inbox = ClinxInbox(file: file, defaults: nil, fixture: true)
            inbox.endpoint = CEFIdentity.fixtureOrigin!
            await inbox.identifier.scan()
            op_cef_test(session.browser, action == 26 ? 21 : action)
            if action == 26 { op_cef_test(session.browser, 21) }
            try await Task.sleep(for: .milliseconds(200))
            await inbox.identifier.scan()
            await inbox.identifier.scan()
            if action == 26 {
                await inbox.identifier.scan(); await inbox.identifier.scan()
                try check(inbox.receipts.count == 1,
                          "multiple source turns discovered in one poll preserve one unique execution binding")
            } else if action == 21 {
                try check(inbox.receipts.count == 1 && inbox.receipts[0].conversation == conversation,
                          "AI source identification and real Observer readback create an automatic binding without manual IDs")
                await inbox.refresh(); await inbox.refresh()
                try check(inbox.receipts.first?.state == .responding,
                          "automatic identification to binding to result receipt to assistant response completes in real CEF")
                let restored = ClinxInbox(file: file, defaults: nil, fixture: true); restored.endpoint = CEFIdentity.fixtureOrigin!
                await restored.identifier.scan()
                try check(restored.receipts.count == 1 && restored.receipts[0].state == .responding,
                          "automatic binding and verified response survive reload without another identification request")
            } else if action == 23 {
                try check(inbox.receipts.isEmpty, "automatic identification does not replay terminal results older than activation")
                await inbox.refresh(identifyConversation: conversation); await inbox.refresh()
                try check(inbox.receipts.first?.state == .responding,
                          "explicit collection can import the identified historical result without a new AI request")
            } else {
                await inbox.identifier.scan()
                try check(inbox.receipts.isEmpty, action == 22 ? "Observer successor/mismatch rejects AI-selected execution" : action == 24 ?
                          "quoted CLINX references with an empty AI creation list do not bind" : "wrong identification nonce cannot create an automatic binding")
            }
            let json = try JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent("identifications.json"))) as! [String: Any]
            let requests = json["requests"] as! [[String: Any]]
            if action == 26 {
                try check(requests.count == 2 && Set(requests.compactMap { $0["witness"] as? String }).count == 2 &&
                          requests.allSatisfy { $0["state"] as? String == "done" },
                          "every source from the same poll is identified once and completes without losing earlier turns")
            } else {
                try check(requests.count == 1, "\(name) repeated collection retains one durable identification request")
            }
            await scene.workspace.close()
        }
    }
}

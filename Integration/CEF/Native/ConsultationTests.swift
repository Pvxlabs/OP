import Foundation

@MainActor extension CEFIntegrationTests {
    func runConsultations() async throws {
        let config = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("consultation-config.json"))) as! [String: Any]
        let command = config["command"] as! [String], taskRef = config["task_ref"] as! String
        let mcp = ConsultationMCP(command: command)
        func call(_ name: String, _ args: [String: Any]) async throws -> [String: Any] {
            let result = try await mcp.call(name, arguments: JSONSerialization.data(withJSONObject: args))
            return try JSONSerialization.jsonObject(with: result) as! [String: Any]
        }
        let conversation = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
        product.openWindow(url: CEFIdentity.url(summary(conversation)))
        let scene = product.windows.last!
        try await wait("consultation fixture readable") { scene.workspace.active?.readableConversation == conversation }
        let session = scene.workspace.active!
        let bridge = product.consultations
        bridge.connect(command: command)
        try await bridge.bind(session: session)
        let binding = bridge.binding!
        try check(binding.conversation_id == conversation, "production CEF inspection binds exact selected conversation through actual CLINX stdio")
        func submit() async throws -> [String: Any] {
            try await call("clinx_submit_consultation", ["request_id":UUID().uuidString.lowercased(),"binding_id":binding.binding_id,"task_ref":taskRef,"question":"Compute 17 + 25; return OP_SYNTHETIC_SUM=42 and echo the request marker."])
        }
        func state(_ requestID: String) async -> String? {
            try? await call("clinx_get_consultation", ["request_id":requestID])["state"] as? String
        }
        func update(_ requestID: String, _ action: String, _ fields: [String: Any] = [:]) async throws -> [String: Any] {
            var args: [String: Any] = ["request_id":requestID,"binding_id":binding.binding_id,"client_id":bridge.clientID,"action":action]
            args.merge(fields) { _, value in value }
            return try await call("clinx_update_consultation", args)
        }
        let first = try await submit(), firstID = first["request_id"] as! String
        try await wait("actual MCP -> OP -> CEF -> cached reply -> MCP") { await state(firstID) == "COMPLETED" }
        let reply = try await call("clinx_get_consultation", ["request_id":firstID])
        try check((reply["reply"] as? String)?.contains("OP_SYNTHETIC_SUM=42") == true,
                  "readable correlated reply returns through actual MCP subprocess and protected SQLite cache")
        let duplicate = try await call("clinx_submit_consultation", ["request_id":firstID,"binding_id":binding.binding_id,"task_ref":taskRef,"question":first["question"]!])
        try check(duplicate["state"] as? String == "COMPLETED" && duplicate["reply_id"] as? String == reply["reply_id"] as? String,
                  "duplicate submit preserves one terminal reply identity")
        let verify = await session.consultation(operation:"verify",conversationID:conversation,requestID:firstID,message:first["prompt"] as! String)
        try check(verify.status == "completed", "repeat readback sees one matching user bubble and same completed assistant")

        op_cef_test(session.browser,10); try await Task.sleep(for: .milliseconds(150))
        let draft = try await submit(), draftID = draft["request_id"] as! String
        try await wait("draft preflight pauses request") { await state(draftID) == "PAUSED" }
        let paused = try await call("clinx_get_consultation", ["request_id":draftID])
        try check(paused["attempted"] as? Int == 0, "draft preflight failure pauses before acquiring any send attempt")
        op_cef_test(session.browser,11); _ = try await update(draftID,"resume")
        try await wait("explicit recovery after draft removal") { await state(draftID) == "COMPLETED" }
        try check(await state(draftID) == "COMPLETED", "explicit resume after safe preflight failure completes the original request")

        // Force a durable crash boundary without a DOM write; recovery must never resend.
        bridge.stop()
        let uncertain = try await submit(), uncertainID = uncertain["request_id"] as! String
        _ = try await update(uncertainID,"begin",["attempt_id":UUID().uuidString.lowercased()])
        let recovered = ConsultationBridge(product: product)
        defer { recovered.stop() }
        try await wait("recovered send reconciles only") { await state(uncertainID) == "PAUSED" }
        let recovery = try await call("clinx_get_consultation", ["request_id":uncertainID])
        try check(recovery["reason"] as? String == "send_outcome_unknown_no_resend", "new bridge instance queries durable send state and pauses absent bubble without replay")
        _ = try await update(uncertainID,"resume")
        try await wait("uncertain explicit resume remains read only") { await state(uncertainID) == "PAUSED" }
        try check(await state(uncertainID) == "PAUSED", "explicit resume cannot grant a second send after an uncertain attempt")
        _ = try await update(uncertainID,"cancel",["reason":"synthetic operator abandonment; never resend"])
        try check(await state(uncertainID) == "CANCELLED", "operator can abandon an uncertain request without replay or blocking later consultations")
        recovered.stop()

        let wrong = await session.consultation(operation:"send",conversationID:a,requestID:UUID().uuidString.lowercased(),message:"must never send")
        try check(wrong.status == "blocked" && wrong.reason == "conversation_mismatch", "CEF refuses a different conversation even with an explicit send operation")
        let http = session.lastHTTPStatus; session.lastHTTPStatus = 429
        let rate = await session.consultation(operation:"inspect")
        session.lastHTTPStatus = http
        try check(rate.status == "blocked", "native HTTP error gate blocks consultation before renderer evaluation")
        session.consultationHTTPFailure = 403; session.consultationHTTPChallenge = true
        let challenge = await session.consultation(operation:"inspect")
        try check(challenge.status == "blocked" && challenge.reason == "http_403_cloudflare_challenge",
                  "Cloudflare challenge remains a hard handoff block with an explicit actionable reason")
        session.consultationHTTPFailure = nil; session.consultationHTTPChallenge = false
        op_cef_test(session.browser,6)
        try await wait("consultation isolated world") { session.mainWorldIsolated }
        try check(session.mainWorldIsolated, "consultation and composer functions remain invisible to remote main world")
    }
}

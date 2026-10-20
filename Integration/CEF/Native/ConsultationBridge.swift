import AppKit
import Foundation

struct ConsultationPageReport: Decodable {
    let request: String
    let status: String
    let reason: String
    let conversation: String?
    let user_message_id: String?
    let reply_id: String?
    let reply: String?
}

@MainActor extension CEFSession {
    func consultation(operation: String, conversationID: String? = nil,
                      requestID: String = "", message: String = "") async -> ConsultationPageReport {
        let request = UUID().uuidString
        let object: [String: Any] = ["consultation": true, "operation": operation,
            "request": request, "request_id": requestID, "conversation": conversationID ?? conversation ?? "",
            "message": message, "deadline": Date().addingTimeInterval(10).timeIntervalSince1970 * 1000]
        guard browser > 0, !retired, !loading, error == nil, consultationHTTPFailure == nil,
              !(lastHTTPStatus.map { $0 >= 400 } ?? true),
              let data = try? JSONSerialization.data(withJSONObject: object),
              let payload = String(data: data, encoding: .utf8), payload.utf8.count <= 64 * 1024 else {
            let reason = consultationHTTPFailure.map { "http_\($0)" + (consultationHTTPChallenge ? "_cloudflare_challenge" : "") }
                ?? "page_not_readable_or_http_error"
            return .init(request: request, status: "blocked", reason: reason,
                         conversation: nil, user_message_id: nil, reply_id: nil, reply: nil)
        }
        return await withCheckedContinuation { continuation in
            guard consultationPending == nil, !hasPendingQuery else {
                continuation.resume(returning: .init(request: request, status: "blocked", reason: "another_composer_operation_pending",
                    conversation: nil, user_message_id: nil, reply_id: nil, reply: nil)); return
            }
            consultationPending = (request, continuation)
            payload.withCString { op_cef_query(browser, $0) }
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(15))
                guard let self, consultationPending?.id == request else { return }
                let pending = consultationPending; consultationPending = nil
                pending?.continuation.resume(returning: .init(request: request, status: "uncertain", reason: "page_operation_timeout_no_resend",
                    conversation: nil, user_message_id: nil, reply_id: nil, reply: nil))
            }
        }
    }
}

/// Local stdio only, using CLINX's existing MCP server. No website credentials.
actor ConsultationMCP {
    let command: [String]
    init(command: [String]) { self.command = command }

    func call(_ name: String, arguments: Data) async throws -> Data {
        let command = command
        return try await Task.detached(priority: .utility) {
            try Self.run(command, name: name, arguments: arguments)
        }.value
    }

    private static func run(_ command: [String], name: String, arguments: Data) throws -> Data {
        guard let executable = command.first, executable.hasPrefix("/"), command.count <= 32,
              FileManager.default.isExecutableFile(atPath: executable),
              let args = try JSONSerialization.jsonObject(with: arguments) as? [String: Any] else {
            throw CocoaError(.fileReadInvalidFileName)
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("op-consultation-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appendingPathComponent("rpc")
        FileManager.default.createFile(atPath: output.path, contents: nil, attributes: [.posixPermissions: 0o600])
        let handle = try FileHandle(forWritingTo: output)
        defer { try? handle.close() }
        let input = Pipe(), process = Process()
        process.executableURL = URL(fileURLWithPath: executable); process.arguments = Array(command.dropFirst())
        process.environment = ["HOME": FileManager.default.homeDirectoryForCurrentUser.path,
                               "PATH": "/usr/bin:/bin:/opt/homebrew/bin", "LANG": "en_US.UTF-8", "PYTHONUNBUFFERED": "1"]
        process.standardInput = input; process.standardOutput = handle; process.standardError = FileHandle.nullDevice
        try process.run()
        let messages: [[String: Any]] = [
            ["jsonrpc":"2.0", "id":1, "method":"initialize", "params":["protocolVersion":"2025-06-18", "capabilities":[:], "clientInfo":["name":"op-consultations", "version":"1"]]],
            ["jsonrpc":"2.0", "method":"notifications/initialized"],
            ["jsonrpc":"2.0", "id":2, "method":"tools/call", "params":["name":name,"arguments":args]]
        ]
        // Write request input on a separate thread too: a non-reading MCP cannot hang OP.
        let bytes = try messages.reduce(into: Data()) { data, message in
            data.append(try JSONSerialization.data(withJSONObject: message)); data.append(10)
        }
        let writer = input.fileHandleForWriting
        DispatchQueue.global(qos: .utility).async {
            try? writer.write(contentsOf: bytes); try? writer.close()
        }
        let deadline = Date().addingTimeInterval(15)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
            if ((try? output.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) > 4 * 1024 * 1024 { break }
        }
        if process.isRunning { process.terminate(); throw CocoaError(.executableRuntimeMismatch) }
        guard process.terminationStatus == 0 else { throw CocoaError(.executableLoad) }
        let data = try Data(contentsOf: output)
        guard data.count <= 4 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
        for line in data.split(separator: 10).reversed() {
            if let envelope = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any], envelope["id"] as? Int == 2,
               let result = envelope["result"] as? [String: Any], result["isError"] as? Bool != true,
               let payload = result["structuredContent"] as? [String: Any] {
                return try JSONSerialization.data(withJSONObject: payload)
            }
        }
        throw CocoaError(.coderReadCorrupt)
    }
}

struct ConsultationBinding: Codable {
    let binding_id: String
    let client_id: String
    let conversation_id: String
}

private struct ConsultationRequest: Decodable {
    let request_id: String
    let binding_id: String
    let prompt: String
    let state: String
    let created_at: Double
    let reason: String
    let send_permitted: Bool?
}

private struct ConsultationInbox: Decodable {
    let binding: ConsultationBinding
    let requests: [ConsultationRequest]
}

@MainActor final class ConsultationBridge {
    private unowned let product: NativeProduct
    let clientID: String
    private var transport: ConsultationMCP?
    private(set) var binding: ConsultationBinding?
    private var loop: Task<Void, Never>?
    private var working = false
    private(set) var status = "未连接咨询 MCP"

    init(product: NativeProduct) {
        self.product = product
        let defaults = UserDefaults.standard
        clientID = defaults.string(forKey: "consultationClientID") ?? UUID().uuidString.lowercased()
        defaults.set(clientID, forKey: "consultationClientID")
        if let command = defaults.stringArray(forKey: "consultationMCPCommand"), !command.isEmpty {
            transport = ConsultationMCP(command: command)
        }
        if let data = defaults.data(forKey: "consultationBinding") {
            binding = try? JSONDecoder().decode(ConsultationBinding.self, from: data)
        }
        start()
    }

    private func start() {
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func stop() { loop?.cancel(); loop = nil }

    func configure() {
        guard !working else { return }
        let panel = NSOpenPanel(); panel.title = "选择 CLINX 咨询 MCP 命令配置（JSON）"
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            guard data.count < 8192, let object = try JSONSerialization.jsonObject(with: data) as? [String: [String]],
                  let command = object["command"], let executable = command.first,
                  command.count <= 32, executable.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: executable) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            connect(command: command)
            showStatus()
        } catch { alert("MCP 配置无效；需要可执行文件的绝对路径和参数数组，不使用 shell。") }
    }

    func connect(command: [String]) {
        transport = ConsultationMCP(command: command); binding = nil
        UserDefaults.standard.set(command, forKey: "consultationMCPCommand")
        UserDefaults.standard.removeObject(forKey: "consultationBinding")
        status = "已连接命令；请打开专用 ChatGPT 对话并绑定"
    }

    func bind(session: CEFSession) async throws {
        let report = await session.consultation(operation: "inspect")
        guard report.status == "ready", let id = report.conversation,
              id == session.conversation, product.focused?.workspace.active === session else {
            status = "BLOCKED: " + report.reason; throw CocoaError(.validationMissingMandatoryProperty)
        }
        let data = try await call("clinx_bind_chatgpt", ["client_id":clientID,"conversation_id":id,"approved":true])
        let next = try JSONDecoder().decode(ConsultationBinding.self, from: data)
        guard next.client_id == clientID, next.conversation_id == id else { throw CocoaError(.coderReadCorrupt) }
        let saved = try JSONEncoder().encode(next)
        UserDefaults.standard.set(saved, forKey: "consultationBinding")
        binding = next; status = "BOUND: \(next.binding_id)\nChatGPT: \(next.conversation_id)"
    }

    func bindCurrent() {
        guard !working, transport != nil, let session = product.focused?.workspace.active else {
            alert("请先连接咨询 MCP 并打开目标 ChatGPT 对话。"); return
        }
        let panel = NSAlert(); panel.messageText = "绑定当前 ChatGPT 对话"
        panel.informativeText = "绑定后，Codex 向此 binding_id 提交的问题会发送到当前选中的这个对话。请确认这是本轮专用合成测试对话。"
        panel.addButton(withTitle: "绑定此对话"); panel.addButton(withTitle: "取消")
        guard panel.runModal() == .alertFirstButtonReturn else { return }
        working = true
        Task {
            defer { working = false }
            do {
                try await bind(session: session)
                showStatus()
            } catch { if !status.hasPrefix("BLOCKED:") { status = "BLOCKED: 绑定 MCP 失败；尚未启用发送" }; showStatus() }
        }
    }

    func showStatus() {
        let detail = binding.map { "\n\nbinding_id: \($0.binding_id)\nconversation_id: \($0.conversation_id)" } ?? ""
        alert(status + detail)
    }

    private func alert(_ message: String) {
        let panel = NSAlert(); panel.messageText = "Codex ↔ ChatGPT 咨询桥接"; panel.informativeText = message
        panel.addButton(withTitle: "确定"); panel.runModal()
    }

    private func call(_ name: String, _ arguments: [String: Any]) async throws -> Data {
        guard let transport else { throw CocoaError(.executableNotLoadable) }
        return try await transport.call(name, arguments: JSONSerialization.data(withJSONObject: arguments))
    }

    private func update(_ request: ConsultationRequest, action: String, fields: [String: Any] = [:]) async throws -> Data {
        guard let binding else { throw CocoaError(.coderReadCorrupt) }
        var args: [String: Any] = ["request_id":request.request_id,"binding_id":binding.binding_id,"client_id":clientID,"action":action]
        args.merge(fields) { _, value in value }
        return try await call("clinx_update_consultation", args)
    }

    private func pause(_ request: ConsultationRequest, _ reason: String) async throws {
        _ = try await update(request, action: "pause", fields: ["reason":reason])
        status = "BLOCKED: \(reason)\nrequest_id: \(request.request_id)"
    }

    private func selectedSession(_ binding: ConsultationBinding) -> CEFSession? {
        guard let scene = product.focused, !scene.workspace.showRecovery,
              let session = scene.workspace.active, session.conversation == binding.conversation_id,
              !session.retired else { return nil }
        return session
    }

    private func poll() async {
        guard !working, let binding, binding.client_id == clientID, transport != nil, !product.quitting else { return }
        working = true; defer { working = false }
        do {
            let data = try await call("clinx_list_consultations", ["binding_id":binding.binding_id,"client_id":clientID])
            let inbox = try JSONDecoder().decode(ConsultationInbox.self, from: data)
            guard inbox.binding.binding_id == binding.binding_id, inbox.binding.client_id == clientID,
                  inbox.binding.conversation_id == binding.conversation_id else { throw CocoaError(.coderReadCorrupt) }
            // Preserve ordering: another question must never interleave with the active reply.
            guard let request = inbox.requests.first else { status = "就绪：没有待处理咨询"; return }
            guard request.binding_id == binding.binding_id else { throw CocoaError(.coderReadCorrupt) }
            if request.state == "PAUSED" { status = "BLOCKED: " + request.reason + "\nrequest_id: " + request.request_id; return }
            guard product.library.enabled, product.library.store != nil else {
                try await pause(request,"reply_protection_unavailable"); return
            }
            guard let session = selectedSession(binding) else {
                try await pause(request,"bound_conversation_not_selected"); return
            }
            let read = await session.consultation(operation: "verify", conversationID: binding.conversation_id,
                requestID: request.request_id, message: request.prompt)
            guard selectedSession(binding) === session else { try await pause(request,"selected_window_changed"); return }
            switch read.status {
            case "completed":
                guard let user = read.user_message_id, let replyID = read.reply_id, let reply = read.reply else {
                    try await pause(request,"reply_metadata_missing"); return
                }
                // Independent existing SQLite protection must agree with DOM identity/body/state.
                let saved = await product.library.messages(binding.conversation_id)
                guard let cached = saved.first(where: { $0.id == replyID }), cached.state == .pageEnded,
                      cached.body.trimmingCharacters(in: .whitespacesAndNewlines) == reply else {
                    if Date().timeIntervalSince1970 - request.created_at > 600 { try await pause(request,"reply_cache_mismatch_or_unavailable") }
                    else { status = "等待回复保护缓存核对" }
                    return
                }
                _ = try await update(request, action: "sent", fields: ["user_message_id":user])
                _ = try await update(request, action: "complete", fields: ["reply_id":replyID,"reply":reply])
                status = "PASS: 已回传可读取、关联核验的回复；等待 Codex 主动读取"
            case "sent":
                if let user = read.user_message_id {
                    _ = try await update(request, action: "sent", fields: ["user_message_id":user])
                }
                if Date().timeIntervalSince1970 - request.created_at > 600 { try await pause(request,"reply_timeout_read_before_resume") }
                else { status = "等待当前请求的 ChatGPT 回复" }
            case "missing":
                guard request.state == "PENDING" else { try await pause(request,"send_outcome_unknown_no_resend"); return }
                let preflight = await session.consultation(operation: "preflight", conversationID: binding.conversation_id,
                    requestID: request.request_id, message: request.prompt)
                guard preflight.status == "ready", selectedSession(binding) === session else {
                    try await pause(request,"preflight_" + preflight.status + ": " + preflight.reason); return
                }
                let grant = try JSONDecoder().decode(ConsultationRequest.self, from: await update(request, action: "begin", fields: ["attempt_id":UUID().uuidString.lowercased()]))
                guard grant.send_permitted == true, selectedSession(binding) === session else { return }
                let sent = await session.consultation(operation: "send", conversationID: binding.conversation_id,
                    requestID: request.request_id, message: request.prompt)
                if sent.status != "sent" { try await pause(request,"composer_send_" + sent.status + ": " + sent.reason) }
                else { status = "已核验提问气泡；等待回复" }
            default: try await pause(request,read.reason.isEmpty ? "page_state_unknown" : read.reason)
            }
        } catch {
            // Persistence/transport ambiguity never grants a subsequent website write.
            status = "BLOCKED: CLINX MCP 不可用或返回不符；恢复后先查询原 request_id"
        }
    }
}

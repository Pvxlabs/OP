import Foundation
import Security
import LocalAuthentication

struct ClinxTask: Decodable, Sendable, Identifiable {
    var id: String { taskRef }
    let schemaVersion: String
    let taskRef: String
    let executionRef: String?
    let title: String?
    let state: String
    let executionState: String
    let codexRunning: Bool
    let mutationBoundary: Boundary
    let finalResult: Result?
    struct Boundary: Decodable, Sendable {
        let observerReadOnly: Bool
        let allowedActions: [String]
    }
    struct Result: Codable, Sendable {
        let executionRef: String
        let status: String
        let summary: String?
        let validation: String?
        let blockers: String?
        let nextState: String?
        let receivedAt: String?
        let textTruncated: Bool
        let redaction: String
    }
    static let terminal: Set<String> = ["COMPLETED", "IN_REVIEW", "BLOCKED", "FAILED", "RECOVERY_REQUIRED", "CANCELLED", "STOPPED"]
    var readOnly: Bool { schemaVersion == "1" && mutationBoundary.observerReadOnly && mutationBoundary.allowedActions.isEmpty }
}

enum ClinxError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case let .invalid(message) = self { message } else { nil } }
}

enum ClinxCredentials {
    static let service = "local.personal.OP.clinx-observer"
    static func read(monitor: Bool) throws -> String {
        let defaults = UserDefaults(suiteName: "com.pvxlabs.clinx.monitor")
        let account = monitor ? defaults?.string(forKey: "monitor.deviceID").map { "device:" + $0 } ?? "p620-observer" : "observer"
        let context = LAContext(); context.interactionNotAllowed = true
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: monitor ? "com.pvxlabs.clinx.monitor.observer" : service,
            kSecAttrAccount as String: account, kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne, kSecUseAuthenticationContext as String: context]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data, let token = String(data: data, encoding: .utf8), !token.isEmpty else {
            throw ClinxError.invalid("无法读取只读凭据，请在连接设置中填写 Observer token。")
        }
        return token
    }
    static func save(_ token: String) throws {
        guard token.range(of: "^[A-Za-z0-9_-]{32,256}$", options: .regularExpression) != nil else {
            throw ClinxError.invalid("Observer token 格式无效。")
        }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "observer", kSecAttrSynchronizable as String: false]
        let values: [String: Any] = [kSecValueData as String: Data(token.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            guard SecItemAdd(query.merging(values) { _, new in new } as CFDictionary, nil) == errSecSuccess else {
                throw ClinxError.invalid("无法保存 Observer 凭据。")
            }
        } else if status != errSecSuccess { throw ClinxError.invalid("无法更新 Observer 凭据。") }
    }
    static var monitorEndpoint: String { UserDefaults(suiteName: "com.pvxlabs.clinx.monitor")?.string(forKey: "monitor.endpoint") ?? "" }
}

private final class ClinxNoRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

struct ClinxObserver: Sendable {
    let endpoint: URL
    let monitor: Bool
    let fixture: Bool
    init(endpoint: String, monitor: Bool = false, fixture: Bool = false) throws {
        guard let url = URL(string: endpoint), url.host != nil, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil, ["", "/"].contains(url.path),
              url.scheme == "https" || (fixture && url.scheme == "http" && url.host == "127.0.0.1") else {
            throw ClinxError.invalid("请输入不含路径、账号或查询参数的 HTTPS Observer 地址。")
        }
        self.endpoint = url; self.monitor = monitor; self.fixture = fixture
    }
    func get<T: Decodable & Sendable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        let config = URLSessionConfiguration.ephemeral
        config.connectionProxyDictionary = [:]; config.httpCookieStorage = nil; config.urlCache = nil
        config.timeoutIntervalForRequest = 10; config.timeoutIntervalForResource = 15
        let session = URLSession(configuration: config, delegate: ClinxNoRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var components = URLComponents(url: endpoint.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !fixture { request.setValue("Bearer " + (try ClinxCredentials.read(monitor: monitor)), forHTTPHeaderField: "Authorization") }
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, http.mimeType == "application/json" else {
            throw ClinxError.invalid("Observer 读取失败（HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)）。")
        }
        var data = Data()
        for try await byte in bytes {
            guard data.count < 2 * 1024 * 1024 else { throw ClinxError.invalid("Observer 响应超过限制。") }
            data.append(byte)
        }
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }
    func health() async throws {
        struct Health: Decodable, Sendable { let schemaVersion: String; let status: String; let readOnly: Bool }
        let value: Health = try await get("v1/health")
        guard value.schemaVersion == "1", value.readOnly, value.status == "OK" else { throw ClinxError.invalid("Observer 只读协议或健康状态不匹配。") }
    }
    func recent() async throws -> [ClinxTask] {
        // Build the query through URLComponents, never embed it into a path component.
        struct Page: Decodable, Sendable { let schemaVersion: String; let items: [ClinxTask] }
        let value: Page = try await get("v1/tasks", query: [.init(name: "state", value: "recent"), .init(name: "offset", value: "0")])
        guard value.schemaVersion == "1", value.items.allSatisfy(\.readOnly) else { throw ClinxError.invalid("Observer 任务协议不匹配。") }
        return value.items
    }
    func task(_ ref: String) async throws -> ClinxTask {
        guard ref.range(of: "^[A-Za-z0-9_-]{1,128}$", options: .regularExpression) != nil else { throw ClinxError.invalid("任务标识无效。") }
        let value: ClinxTask = try await get("v1/tasks/" + ref)
        guard value.readOnly, value.taskRef == ref else { throw ClinxError.invalid("Observer 任务身份或只读协议不匹配。") }
        return value
    }
}

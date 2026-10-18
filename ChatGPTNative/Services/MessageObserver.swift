import WebKit

@MainActor
final class MessageObserver: NSObject, WKScriptMessageHandlerWithReply {
    static let world = WKContentWorld.world(name: "ChatGPTNative.Snapshots.v1")
    static let handlerName = "localReplySnapshot"
    var receive: ((ObservedConversation) async -> Bool)?
    weak var webView: WKWebView?
    private let allowFixtures: Bool
    private let initiallyEnabled: Bool

    init(allowFixtures: Bool = false, enabled: Bool = true) {
        self.allowFixtures = allowFixtures
        initiallyEnabled = enabled
    }

    static func source(allowFixtures: Bool = false, enabled: Bool = true) throws -> String {
        guard let url = Bundle.main.url(forResource: "MessageObserver", withExtension: "js") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try String(contentsOf: url, encoding: .utf8)
            .replacingOccurrences(of: "__ALLOW_FIXTURES__", with: allowFixtures ? "true" : "false")
            .replacingOccurrences(of: "__CAPTURE_ENABLED__", with: enabled ? "true" : "false")
    }
    func install(on controller: WKUserContentController) throws {
        let script = try Self.source(allowFixtures: allowFixtures, enabled: initiallyEnabled)
        controller.addScriptMessageHandler(self, contentWorld: Self.world, name: Self.handlerName)
        controller.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentEnd,
                                             forMainFrameOnly: true, in: Self.world))
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage,
                               replyHandler: @escaping @MainActor (Any?, String?) -> Void) {
        let origin = message.frameInfo.securityOrigin
        let official = origin.protocol == "https" && origin.host == "chatgpt.com"
        let fixture = allowFixtures && origin.protocol == "snapshot-fixture" && origin.host == "local"
        guard message.webView === webView, message.frameInfo.isMainFrame, official || fixture,
              let dictionary = message.body as? [String: Any],
              JSONSerialization.isValidJSONObject(dictionary),
              let data = try? JSONSerialization.data(withJSONObject: dictionary), data.count <= 3 * 1024 * 1024,
              let batch = try? JSONDecoder().decode(ObservedConversation.self, from: data),
              let url = message.webView?.url,
              (fixture || SnapshotIdentity.conversation(in: url) == batch.conversationID.lowercased()) else {
            replyHandler(false, nil); return
        }
        Task { replyHandler(await receive?(batch) ?? false, nil) }
    }
}

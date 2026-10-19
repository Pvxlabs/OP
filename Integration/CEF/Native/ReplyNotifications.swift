import AppKit
import UserNotifications

struct ReplyCompletion: Decodable {
    let documentID: String
    let conversationID: String
    let sequence: Int
}

@MainActor final class ReplyNotifications: NSObject, UNUserNotificationCenterDelegate {
    var enabled = UserDefaults.standard.object(forKey: "replyNotificationsEnabled") as? Bool ?? true
    private let isActive: () -> Bool
    private let deliver: (ReplyCompletion) -> Void
    private var delivered: [Int64: (document: String, sequence: Int)] = [:]
    init(isActive: @escaping () -> Bool = { NSApp.isActive }, deliver: ((ReplyCompletion) -> Void)? = nil) {
        self.isActive = isActive
        self.deliver = deliver ?? { event in
            guard !CommandLine.arguments.contains("--self-test") else { return }
            let content = UNMutableNotificationContent()
            content.title = "OP"
            content.body = "ChatGPT 已完成回复，点击查看。"
            content.sound = .default
            content.userInfo = ["conversationID": event.conversationID]
            let request = UNNotificationRequest(identifier: event.documentID + ":" + String(event.sequence), content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                if error != nil { NSLog("OP completion notification could not be scheduled") }
            }
        }
        super.init()
    }
    func start() {
        guard !CommandLine.arguments.contains("--self-test") else { return }
        UNUserNotificationCenter.current().delegate = self
        if enabled { requestPermission() }
    }
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if error != nil { NSLog("OP notification authorization request failed") }
        }
    }
    func receive(_ json: String, session: CEFSession) {
        guard !session.retired, let event = try? JSONDecoder().decode(ReplyCompletion.self, from: Data(json.utf8)),
              SnapshotIdentity.valid(event.documentID), SnapshotIdentity.valid(event.conversationID),
              event.conversationID == session.conversation, event.sequence > 0 else { return }
        if let previous = delivered[session.id], previous.document == event.documentID, previous.sequence >= event.sequence { return }
        // Consume foreground/off events too: moving to the background must not replay one.
        delivered[session.id] = (event.documentID, event.sequence)
        guard enabled, !isActive() else { return }
        deliver(event)
    }
    func forget(_ key: Int64) { delivered.removeValue(forKey: key) }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // Check again at presentation time, in case the user has returned to OP.
        await MainActor.run { NSApp.isActive ? [] : [.banner, .sound] }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = response.notification.request.content.userInfo["conversationID"] as? String
        Task { @MainActor in
            if let id, SnapshotIdentity.valid(id) {
                let product = NativeProduct.shared
                if let scene = product.windows.first(where: { $0.workspace.active?.conversation == id }) {
                    scene.window?.makeKeyAndOrderFront(nil)
                } else { product.openWindow(url: URL(string: "https://chatgpt.com/c/" + id)) }
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        completionHandler()
    }
}

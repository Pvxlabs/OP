import Foundation

@MainActor extension CEFIntegrationTests {
    func runReplyNotifications() async throws {
        let original = product.replyNotifications
        var active = false, notices: [String] = []
        let notifications = ReplyNotifications(isActive: { active }, deliver: { notices.append($0.conversationID) })
        notifications.enabled = true
        product.replyNotifications = notifications
        defer { product.replyNotifications = original }
        let id = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
        product.openWindow(url: CEFIdentity.url(summary(id)))
        let scene = product.windows.last!
        try await wait("notification fixture loaded") { scene.workspace.active?.readableConversation == id }
        let session = scene.workspace.active!
        try await Task.sleep(for: .seconds(2))
        try check(notices.isEmpty, "opening completed history never notifies")
        op_cef_test(session.browser, 1)
        try await Task.sleep(for: .milliseconds(200))
        op_cef_test(session.browser, 2)
        try await wait("background completion event") { notices.count == 1 }
        try check(notices == [id], "observed generation completion sends one background notification")
        op_cef_test(session.browser, 2)
        try await Task.sleep(for: .seconds(2))
        try check(notices.count == 1, "repeated complete DOM does not duplicate notifications")
        active = true
        op_cef_test(session.browser, 1)
        try await Task.sleep(for: .milliseconds(200))
        op_cef_test(session.browser, 2)
        try await Task.sleep(for: .seconds(2))
        try check(notices.count == 1, "foreground completion is consumed without notifying")
        active = false
        op_cef_test(session.browser, 2)
        try await Task.sleep(for: .seconds(2))
        try check(notices.count == 1, "moving to background never replays a foreground completion")
        op_cef_test(session.browser, 1)
        try await Task.sleep(for: .milliseconds(200))
        op_cef_test(session.browser, 28)
        try await Task.sleep(for: .seconds(2))
        try check(notices.count == 1, "manual stop is not reported as normal completion")
        op_cef_test(session.browser, 1)
        try await Task.sleep(for: .milliseconds(200))
        op_cef_test(session.browser, 0)
        op_cef_test(session.browser, 13)
        try await Task.sleep(for: .seconds(2))
        try check(notices.count == 1, "error replies never produce a completion notification")
        // The notification signal is independent of reply snapshot permissions/identity.
        let capture = product.library.enabled
        product.library.enabled = false; product.setCapture(false)
        op_cef_test(session.browser, 8)
        op_cef_test(session.browser, 1)
        try await Task.sleep(for: .milliseconds(200))
        op_cef_test(session.browser, 2)
        try await wait("completion without snapshots") { notices.count == 2 }
        product.library.enabled = capture; product.setCapture(capture)
        try check(notices.count == 2, "completion reminders work with snapshots paused and no message capture identity")
        notifications.enabled = false
        op_cef_test(session.browser, 1)
        try await Task.sleep(for: .milliseconds(200))
        op_cef_test(session.browser, 2)
        try await Task.sleep(for: .seconds(2))
        try check(notices.count == 2, "disabled completion reminders remain silent")
        await scene.workspace.close()
    }
}

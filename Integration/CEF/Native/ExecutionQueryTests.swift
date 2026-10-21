import Foundation

@MainActor extension CEFIntegrationTests {
    func runExecutionQuery() async throws {
        let conversation = "88888888-8888-4888-8888-888888888888"
        product.openWindow(url: CEFIdentity.url(summary(conversation)))
        let scene = product.windows.last!
        try await wait("query fixture conversation") { scene.workspace.active?.readableConversation == conversation }
        let session = scene.workspace.active!
        func control(_ action: Int32) async throws {
            op_cef_test(session.browser, action)
            try await Task.sleep(for: .milliseconds(150))
        }
        func request() async -> ExecutionQueryReport { await session.queryExecution() }
        // The query does not depend on local capture or identified assistant replies.
        try await control(8)
        let loading = session.loading
        session.loading = true
        let notReady = await request()
        session.loading = loading
        try check(notReady.status == "waiting", "loading page cannot receive a query")
        try await control(10)
        let draft = await request()
        try check(draft.status == "waiting" && draft.reason.contains("草稿"), "existing draft is preserved without submitting a query")
        try await control(11); try await control(12)
        let streaming = await request()
        try check(streaming.status == "sent", "streaming turn metadata does not block an explicit query")
        try await control(38)
        let queued = await request()
        try check(queued.status == "sent", "visible Stop control does not block sending through the webpage queue control")
        try await control(39); try await control(40)
        let startsStreaming = await request()
        try check(startsStreaming.status == "sent", "generation starting during insertion does not block or stop the query")
        try await control(39)
        try await control(13); try await control(14)
        let modal = await request()
        try check(modal.status == "waiting" && modal.reason.contains("对话框"), "visible modal blocks the query")
        try await control(15); try await control(16)
        let attachment = await request()
        try check(attachment.status == "waiting" && attachment.reason.contains("附件"), "attachment is preserved without submitting a query")
        try await control(17)
        try await control(33)
        let contentsBubble = await request()
        try check(contentsBubble.status == "sent", "visible query inside a display:contents user wrapper confirms submission")
        let windows = product.windows.count
        scene.collectButton.performClick(nil)
        try check(!scene.collectButton.isEnabled, "collect button disables immediately while sending")
        scene.collectButton.performClick(nil)
        try await wait("collect button query sent") { scene.queryReport != nil }
        try check(scene.queryReport?.status == "sent" && scene.collectButton.isEnabled,
                  "native collect button sends the fixed query and verifies a new user bubble")
        try check(product.windows.count == windows, "collect opens no inbox or extra window")
        let again = await request()
        try check(again.status == "sent", "a later explicit click can send the identical query again")
        try await control(36)
        let replaced = await request()
        try check(replaced.status == "sent", "a new query confirms even when an older identical bubble is unmounted")
        try await control(34)
        let hidden = await request()
        try check(hidden.status == "uncertain", "a hidden matching user bubble does not confirm submission")
        try await control(35)
        try await control(18)
        let pending = Task { await request() }
        try await Task.sleep(for: .milliseconds(200))
        let overlapping = await request()
        try check(overlapping.status == "waiting", "overlapping send is rejected without a duplicate query")
        let unavailable = await pending.value
        try check(unavailable.status == "uncertain", "disabled send button leaves query as a draft without retrying")
        let retainedDraft = await request()
        try check(retainedDraft.status == "waiting" && retainedDraft.reason.contains("草稿"), "unsent query draft is preserved on the next click")
        try await control(19); try await control(24)
        let edited = await request()
        try check(edited.status == "uncertain", "user edit during insertion stops submission and preserves changed draft")
        try await control(19); try await control(26)
        let newModal = await request()
        try check(newModal.status == "uncertain", "modal appearing during insertion stops submission")
        try await control(15); try await control(19); try await control(20)
        let unknown = await request()
        try check(unknown.status == "uncertain", "remounted history without a new matching user bubble remains uncertain, never auto-resends")
        try await control(37)
        let roleOnlyRemount = await request()
        try check(roleOnlyRemount.status == "uncertain", "role-only history remount without a stable message key cannot confirm a new query")
        try await control(21); try await control(25)
        let navigated = await request()
        try check(navigated.status == "uncertain", "conversation change during insertion prevents submission to another chat")
        await scene.workspace.close()
    }
}

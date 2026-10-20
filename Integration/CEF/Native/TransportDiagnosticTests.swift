import Foundation

@MainActor extension CEFIntegrationTests {
    func runTransportDiagnostics() async throws {
        product.openWindow(url: CEFIdentity.url(summary("88888888-8888-4888-8888-888888888888")))
        let workspace = product.windows.last!.workspace
        try await wait("transport fixture loaded") { workspace.active?.loading == false && (workspace.active?.browser ?? 0) > 0 }
        let session = workspace.active!
        let allowed = Set(["phase", "request", "stream", "status", "http", "error", "bytes", "milliseconds", "route", "method", "mime", "challenge"])
        for (action, label) in [(Int32(29), "clean EOF"), (30, "truncated response"), (31, "HTTP failure"), (32, "cancellation")] {
            transportEvents.removeAll()
            op_cef_test(session.browser, action)
            try await wait("transport " + label) {
                self.transportEvents.contains { $0.browser == session.browser && $0.value["phase"] as? String == "end" }
            }
            let events = transportEvents.filter { $0.browser == session.browser }.map(\.value)
            let end = events.first { $0["phase"] as? String == "end" }!
            try check(events.allSatisfy { Set($0.keys) == allowed }, "\(label) emits only allowlisted transport metadata")
            let status = end["status"] as? Int, http = end["http"] as? Int
            if action == 29 {
                try check(status == 1 && http == 200 && end["stream"] as? Bool == true &&
                          (end["bytes"] as? Double ?? 0) > 0,
                          "clean SSE EOF records transport success without certifying answer completeness")
            } else if action == 30 {
                try check(status == 4 && http == 200 && (end["error"] as? Int ?? 0) < 0,
                          "truncated HTTP 200 stream records failure and a Chromium error")
            } else if action == 31 {
                try check(http == 429, "HTTP failure remains distinguishable from stream success")
            } else {
                // Chromium reports AbortController as UR_FAILED + ERR_ABORTED,
                // rather than the top-level CEF UR_CANCELED status.
                try check(status != 1 && end["error"] as? Int == -3,
                          "aborted fetch records ERR_ABORTED separately from content-length failure")
            }
            try check(events.filter { $0["phase"] as? String == "end" }.count == 1,
                      "\(label) emits one terminal transport event")
        }
        await workspace.close()
    }
}

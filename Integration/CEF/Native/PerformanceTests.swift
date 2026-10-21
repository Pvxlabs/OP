import Foundation

@MainActor extension CEFIntegrationTests {
    func runPerformanceProbe(_ session: CEFSession) async throws {
        let before = await product.library.messages(a)
        performanceReports.removeValue(forKey: session.browser)
        op_cef_action(session.browser, 5)
        for _ in 0..<400 {
            if performanceReports[session.browser] != nil { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        guard let report = performanceReports[session.browser], let page = report["page"] as? [String: Any] else {
            throw CocoaError(.validationMissingMandatoryProperty)
        }
        try check(page["status"] as? String == "measured" && page["sameConversation"] as? Bool == true,
                  "manual performance probe completes in the matching isolated document")
        try check((page["elapsedMilliseconds"] as? Double ?? 0) >= 30000,
                  "performance probe measures its declared bounded window")
        let encoded = String(data: try JSONSerialization.data(withJSONObject: report), encoding: .utf8)!
        try check(!encoded.contains(a) && !encoded.contains("Synthetic protected response") && !encoded.contains("http"),
                  "performance report excludes conversation identity, body text and URLs")
        try check((await product.library.messages(a)).map(\.fingerprint) == before.map(\.fingerprint),
                  "read-only performance probe preserves protected reply fingerprints")
        performanceReports.removeValue(forKey: session.browser)
        session.readableConversation = nil
        op_cef_action(session.browser, 6)
        try await wait("measured reload accepts the first official reply") { session.readableConversation == self.a }
        for _ in 0..<400 {
            if performanceReports[session.browser] != nil { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        let loadProbe = performanceReports[session.browser]?["page"] as? [String: Any]
        try check(loadProbe?["status"] as? String == "measured" && loadProbe?["startDocumentMilliseconds"] is Double,
                  "measured reload starts a bounded observer cost probe in the new isolated document")
        op_cef_test(session.browser, 137)
        try await Task.sleep(for: .seconds(1))
        op_cef_action(session.browser, 7)
        guard let load = performanceReports[session.browser], let events = load["events"] as? [[String: Any]] else {
            throw CocoaError(.validationMissingMandatoryProperty)
        }
        let phases = events.compactMap { $0["phase"] as? String }
        try check(load["kind"] as? String == "reload" && load["samePage"] as? Bool == true && phases.first == "reloadRequested" &&
                  phases.contains("documentLoadEnd") && phases.contains("firstReplyBatch") && phases.contains("firstReplyAccepted"),
                  "reload timing spans document replacement through protected reply acceptance")
        try check(phases.contains("conversationStart") && phases.contains("conversationResponse") &&
                  phases.contains("documentRequestStart") && phases.contains("documentRequestResponse") && phases.contains("documentRequestEnd") &&
                  events.contains { $0["phase"] as? String == "conversationEnd" && $0["http"] as? Int == 200 &&
                      ($0["requestMilliseconds"] as? Double ?? 0) >= 140 && ($0["bytes"] as? Double ?? 0) > 0 },
                  "passive reload timing separates conversation response and transfer completion")
        let loadJSON = String(data: try JSONSerialization.data(withJSONObject: load), encoding: .utf8)!
        try check(!loadJSON.contains(a) && !loadJSON.contains("Synthetic protected response") && !loadJSON.contains("http://"),
                  "reload timing excludes conversation identity, body and URL")
        try check((await product.library.messages(a)).map(\.fingerprint) == before.map(\.fingerprint),
                  "measured reload preserves protected reply fingerprints")
    }
}

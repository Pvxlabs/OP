import Foundation
import AppKit

@MainActor final class CEFIntegrationTests {
    let product: NativeProduct
    let a = "11111111-1111-4111-8111-111111111111"
    let b = "33333333-3333-4333-8333-333333333333"
    let c = "44444444-4444-4444-8444-444444444444"
    let d = "55555555-5555-4555-8555-555555555555"
    var checks: [String] = []
    var metrics: [String: Double] = [:]
    var transportEvents: [(browser: Int32, value: [String: Any])] = []
    var performanceReports: [Int32: [String: Any]] = [:]
    let root: URL
    init(product: NativeProduct) {
        self.product = product
        let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--evidence=") })!
        root = URL(fileURLWithPath: String(arg.dropFirst("--evidence=".count)))
    }
    func event(_ name: String, browser: Int32, value: String) {
        if name == "transport", let metadata = try? JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any] {
            transportEvents.append((browser, metadata))
        }
        if ["performance", "loadPerformance"].contains(name), let report = try? JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any] {
            performanceReports[browser] = report
        }
        guard !["address", "title"].contains(name) else { return }
        let entry: [String: Any] = ["event": name, "browser": browser, "value": value, "uptime": ProcessInfo.processInfo.systemUptime]
        guard let data = try? JSONSerialization.data(withJSONObject: entry), let handle = try? FileHandle(forWritingTo: root.appendingPathComponent("events.ndjson")) else {
            try? Data().write(to: root.appendingPathComponent("events.ndjson")); return
        }
        try? handle.seekToEnd(); try? handle.write(contentsOf: data + Data([10])); try? handle.close()
    }
    func check(_ ok: Bool, _ label: String) throws {
        if !ok { throw NSError(domain: "CEFIntegration", code: 1, userInfo: [NSLocalizedDescriptionKey: label]) }
        checks.append(label)
    }
    func wait(_ label: String, _ predicate: @escaping @MainActor () async -> Bool) async throws {
        for _ in 0..<150 { if await predicate() { return }; try await Task.sleep(for: .milliseconds(100)) }
        throw NSError(domain: "CEFIntegration", code: 2, userInfo: [NSLocalizedDescriptionKey: "Timed out: " + label])
    }
    func summary(_ id: String) -> ConversationSummary { .init(id: id, updatedAt: Date(), messageCount: 1) }
    func mode(_ value: String) throws {
        try JSONSerialization.data(withJSONObject: [a: value]).write(to: root.appendingPathComponent("mode.json"), options: .atomic)
    }
    func headerVisual(_ scene: ProductWindow, _ name: String, hover: Bool = false) throws {
        guard CommandLine.arguments.contains("--header-visuals"), let window = scene.window,
              let frame = window.contentView?.superview else { return }
        let event = NSEvent.mouseEvent(with: .mouseMoved, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 0, pressure: 0)!
        if hover { scene.collectButton.mouseEntered(with: event) }
        defer { if hover { scene.collectButton.mouseExited(with: event) } }
        frame.layoutSubtreeIfNeeded(); frame.displayIfNeeded()
        let area = NSRect(x: 0, y: frame.isFlipped ? 0 : frame.bounds.maxY - 40, width: frame.bounds.width, height: 40)
        guard let bitmap = frame.bitmapImageRepForCachingDisplay(in: area) else { throw CocoaError(.fileWriteUnknown) }
        frame.cacheDisplay(in: area, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: root.appendingPathComponent(name + ".png"))
    }
    func run() async {
        let began = ContinuousClock.now
        let restart = CommandLine.arguments.contains("--restart-check")
        do {
            if CommandLine.arguments.contains("--performance-check") {
                try mode("normal")
                product.openWindow(url: CEFIdentity.url(summary(a)))
                let workspace = product.windows.last!.workspace
                try await wait("performance fixture readiness") { workspace.active?.readableConversation == self.a }
                guard let session = workspace.active else { throw CocoaError(.validationMissingMandatoryProperty) }
                try await runPerformanceProbe(session)
            } else if CommandLine.arguments.contains("--consultation-check") {
                try await runConsultations()
            } else if CommandLine.arguments.contains("--transport-check") {
                try await runTransportDiagnostics()
            } else if restart {
                let saved = await product.library.messages(a)
                try check(saved.count == 1 && saved[0].body.hasPrefix("Synthetic protected response"), "SQLite snapshot persists across process restart")
                try check(saved[0].state != .streaming, "restart never promotes unfinished stream")
                product.openWindow(url: CEFIdentity.url(summary(a)))
                let restored = product.windows.last!.workspace
                try await wait("silent startup browser creation") { restored.active?.browser ?? 0 > 0 }
                try check(!restored.showRecovery && restored.active?.host.isHidden == false, "startup with existing SQLite copies shows official browser only")
                try await wait("silent startup official content") { restored.active?.readableConversation == self.a }
                try check(!restored.showRecovery && restored.active?.host.superview != nil, "startup never flashes a local transcript during official synchronization")
            } else {
                try mode("normal")
                try check(!FileManager.default.fileExists(atPath: Bundle.main.bundlePath + "/Contents/Frameworks/OPCEFIntegration Helper (Alerts).app"),
                          "optional CEF Alerts app is absent while native reply notifications remain available")
                product.openWindow(url: CEFIdentity.url(summary(a)))
                let scene = product.windows.last!, workspace = scene.workspace
                try await wait("CEF bridge and SQLite save") { (await self.product.library.messages(self.a)).first?.state == .pageEnded }
                guard let first = workspace.active else { throw CocoaError(.validationMissingMandatoryProperty) }
                try check(scene.window!.frame.width <= 1280, "native window size remains bounded during SwiftUI local recovery")
                let initial = await product.library.messages(a)
                try await runPerformanceProbe(first)
                try check(first.observerAvailable && first.browser > 0, "isolated CEF observer installed and real renderer snapshot saved")
                try check(initial.count == 1 && initial[0].body.utf8.count > 4000, "full synthetic rendered body captured")
                try check(initial[0].state == .pageEnded, "DOM turn complete stays pageEnded, never server-complete")
                op_cef_test(first.browser, 6)
                try await wait("isolated bridge visibility") { first.mainWorldIsolated }
                try check(first.mainWorldIsolated, "remote main world cannot access native binding or observer controls")
                op_cef_test(first.browser, 7)
                try await Task.sleep(for: .seconds(2))
                try check((await product.library.messages(a)).count == 1, "subframe snapshot rejected despite same origin and conversation")
                let hash = initial[0].fingerprint
                let originalAppearance = product.appearance
                NSApp.activate(ignoringOtherApps: true)
                scene.window!.makeKeyAndOrderFront(nil)
                try await wait("test window focus") { NSApp.isActive && scene.window!.isKeyWindow }
                product.setAppearance(.light)
                metrics["titlebarPoints"] = scene.window!.frame.height - scene.window!.contentLayoutRect.height
                try check(abs(metrics["titlebarPoints"]! - 40) < 0.1, "native titlebar measured height is 40 pt")
                let color = scene.window!.backgroundColor.usingColorSpace(.sRGB)!
                try check([color.redComponent,color.greenComponent,color.blueComponent].allSatisfy { abs($0 - 249.0/255) < 0.0001 }, "native titlebar background is #F9F9F9")
                scene.window!.contentView?.superview?.layoutSubtreeIfNeeded()
                try await Task.sleep(for: .milliseconds(100))
                let lightCollect = scene.collectButton.convert(scene.collectButton.bounds, to: nil)
                let lightRefresh = scene.refreshButton.convert(scene.refreshButton.bounds, to: nil)
                let lightTitle = scene.titleLabel.convert(scene.titleLabel.bounds, to: nil)
                let lightControls = [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].map {
                    let button = scene.window!.standardWindowButton($0)!
                    return button.convert(button.bounds, to: nil)
                }
                let lightCollectImage = scene.collectButton.image, lightRefreshImage = scene.refreshButton.image
                metrics["lightIsKey"] = scene.window!.isKeyWindow ? 1 : 0
                metrics["lightAppActive"] = NSApp.isActive ? 1 : 0
                metrics["lightTitleRed"] = scene.titleLabel.textColor!.usingColorSpace(.sRGB)!.redComponent
                metrics["lightCollectHidden"] = scene.collectButton.isHidden ? 1 : 0
                metrics["lightRefreshHidden"] = scene.refreshButton.isHidden ? 1 : 0
                try headerVisual(scene, "light-focused")
                try check(!scene.collectButton.isHidden && !scene.refreshButton.isHidden &&
                          abs(scene.titleLabel.textColor!.usingColorSpace(.sRGB)!.redComponent - 49.0/255) < 0.0001 &&
                          scene.collectButton.contentTintColor == scene.titleLabel.textColor && scene.refreshButton.contentTintColor == scene.titleLabel.textColor,
                          "focused light header shows both icons with the existing light title palette")
                try headerVisual(scene, "light-focused")
                try headerVisual(scene, "light-hover", hover: true)
                let navigationBeforeAppearance = first.navigationCount
                product.setAppearance(.dark)
                try check(scene.window!.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua,
                          "night mode applies native dark appearance")
                let darkBackground = scene.window!.backgroundColor.usingColorSpace(.sRGB)!
                scene.window!.contentView?.superview?.layoutSubtreeIfNeeded()
                try await Task.sleep(for: .milliseconds(100))
                let collectFrame = scene.collectButton.convert(scene.collectButton.bounds, to: nil)
                let refreshFrame = scene.refreshButton.convert(scene.refreshButton.bounds, to: nil)
                let close = scene.window!.standardWindowButton(.closeButton)!
                let closeFrame = close.convert(close.bounds, to: nil)
                metrics["nightCollectRightInset"] = scene.window!.frame.width - collectFrame.maxX
                metrics["nightRefreshRightInset"] = scene.window!.frame.width - refreshFrame.maxX
                metrics["nightButtonTop"] = scene.window!.frame.height - collectFrame.maxY
                metrics["nightControlCenterX"] = closeFrame.midX
                metrics["nightControlCenterY"] = scene.window!.frame.height - closeFrame.midY
                try check(abs(collectFrame.width - 32) < 0.01 && abs(collectFrame.height - 30) < 0.01 &&
                          abs(metrics["nightCollectRightInset"]! - 48) < 0.01 &&
                          abs(metrics["nightRefreshRightInset"]! - 12) < 0.01 &&
                          abs(metrics["nightButtonTop"]! - 5.002) < 0.01 &&
                          abs(closeFrame.midX - 18.5) < 0.01 && abs(metrics["nightControlCenterY"]! - 19.5) < 0.01 &&
                          scene.titleLabel.font?.fontName == "Inter-Bold",
                          "Figma night header positions, button bounds and bundled font match the design")
                let darkControls = [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].map {
                    let button = scene.window!.standardWindowButton($0)!
                    return button.convert(button.bounds, to: nil)
                }
                try check(lightCollect == collectFrame && lightRefresh == refreshFrame &&
                          lightTitle == scene.titleLabel.convert(scene.titleLabel.bounds, to: nil) && lightControls == darkControls &&
                          scene.collectButton.image === lightCollectImage && scene.refreshButton.image === lightRefreshImage,
                          "light header title, both glyphs and all traffic lights match the approved night geometry")
                try check(abs(darkBackground.redComponent - 28.0/255) < 0.0001 &&
                          scene.refreshButton.contentTintColor == scene.titleLabel.textColor &&
                          scene.collectButton.contentTintColor == scene.titleLabel.textColor,
                          "night titlebar is dark and both icons match its title")
                try headerVisual(scene, "dark-focused")
                try headerVisual(scene, "dark-hover", hover: true)
                try check(UserDefaults.standard.string(forKey: "nativeAppearance") == "dark", "appearance selection is persisted")
                product.setAppearance(.system)
                try check(NSApp.appearance == nil, "follow-system mode removes the native appearance override")
                try check(first.navigationCount == navigationBeforeAppearance && workspace.active === first,
                          "appearance changes preserve the mounted conversation without navigation")
                product.setAppearance(originalAppearance)
                op_cef_test(first.browser, 8)
                try await Task.sleep(for: .seconds(1))
                try check((await product.library.messages(a)).first?.fingerprint == hash, "missing DOM conversation identity is rejected without overwriting prior copy")
                op_cef_action(first.browser, 0)
                try await Task.sleep(for: .seconds(2))
                op_cef_test(first.browser, 0)
                try await wait("error observation") { (await self.product.library.messages(self.a)).first?.lastObservation == .readFailure }
                try check((await product.library.messages(a)).first?.fingerprint == hash, "error placeholder preserves saved reply")
                op_cef_test(first.browser, 3)
                try await Task.sleep(for: .seconds(1))
                try check((await product.library.messages(a)).first?.fingerprint == hash, "empty DOM preserves saved reply")
                try mode("429"); op_cef_action(first.browser, 0)
                try await wait("429") { first.lastHTTPStatus == 429 }
                try check((await product.library.messages(a)).first?.fingerprint == hash, "HTTP 429 cannot overwrite saved text")
                try mode("403"); op_cef_action(first.browser, 0)
                try await wait("403") { first.lastHTTPStatus == 403 }
                try check((await product.library.messages(a)).first?.fingerprint == hash, "HTTP 403 cannot overwrite saved text")
                try check(!workspace.showRecovery && first.host.superview != nil && !first.host.isHidden,
                          "HTTP failure keeps official webpage visible without opening recovery")
                try mode("normal"); op_cef_action(first.browser, 0)
                try await wait("reload recovery") { first.error == nil && first.readableConversation == self.a }
                try check((await product.library.messages(a)).count == 1, "reload recovery deduplicates same message")
                op_cef_test(first.browser, 4)
                try await Task.sleep(for: .seconds(2))
                try check((await product.library.messages(a)).first?.fingerprint == hash, "DOM conversation identity mismatch rejected")
                op_cef_action(first.browser, 0)
                try await wait("identity recovered") { first.readableConversation == self.a }
                let browser = first.browser, attachments = first.attachmentCount
                workspace.open(summary(b))
                try await wait("second conversation") { workspace.active?.readableConversation == self.b }
                workspace.open(summary(a))
                try await Task.sleep(for: .milliseconds(300))
                try check(workspace.active === first && first.browser == browser && first.attachmentCount == attachments, "hot selection retains BrowserSession and CEF NSView")
                try check(first.navigationCount == 1, "hot switch has no explicit new navigation")
                metrics["nativeHotSelectionMs"] = workspace.selectionMilliseconds
                workspace.open(summary(c))
                try check(!workspace.showRecovery, "cold selection without a snapshot never opens local recovery")
                try await wait("third") { workspace.active?.readableConversation == self.c }
                workspace.open(summary(d)); try await wait("fourth") { workspace.active?.readableConversation == self.d }
                try check(workspace.sessions.count == 3, "per-window LRU stays bounded at three")
                workspace.trim()
                try check(workspace.sessions.count == 1, "memory pressure evicts inactive sessions only")
                workspace.open(summary(a))
                try check(!workspace.showRecovery, "cold selection with a saved snapshot keeps the official webpage")
                try await wait("cold official content") { workspace.active?.readableConversation == self.a }
                try check(workspace.active?.host.superview != nil && workspace.active?.host.isHidden == false && !workspace.showRecovery,
                          "official browser stays visible after cold content loads")
                try check((await product.library.messages(a)).count == 1, "cold recovery preserves deduplication")
                workspace.recover()
                try check(workspace.showRecovery && workspace.recoveryID == a, "local copies open only through explicit recovery")
                workspace.open(summary(a))
                try await Task.sleep(for: .milliseconds(100))
                try check(!workspace.showRecovery && workspace.active?.host.isHidden == false,
                          "opening an official conversation dismisses explicit local recovery")
                product.openWindow(url: CEFIdentity.url(summary(b)))
                try await wait("new window") { self.product.windows.last?.workspace.active?.readableConversation == self.b }
                try check(product.windows.last!.workspace.active!.browser != workspace.active!.browser, "simultaneous windows own distinct CEF browsers and views")
                product.setAppearance(.dark)
                try check(product.windows.allSatisfy { $0.window!.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua },
                          "night appearance reaches every open native window")
                try check(!scene.window!.isKeyWindow && abs(scene.titleLabel.textColor!.usingColorSpace(.sRGB)!.redComponent - 110.0/255) < 0.0001 && scene.refreshButton.isHidden && scene.collectButton.isHidden,
                          "Figma inactive night title is #6E6E6E and right icons are hidden")
                try headerVisual(scene, "dark-unfocused")
                product.setAppearance(.light)
                try check(!scene.window!.isKeyWindow && abs(scene.titleLabel.textColor!.usingColorSpace(.sRGB)!.redComponent - 110.0/255) < 0.0001 && scene.refreshButton.isHidden && scene.collectButton.isHidden && scene.refreshButton.contentTintColor == scene.titleLabel.textColor && scene.collectButton.contentTintColor == scene.titleLabel.textColor,
                          "inactive light header matches night behavior: muted title and hidden right icons")
                try headerVisual(scene, "light-unfocused")
                product.setAppearance(originalAppearance)
                let revisionBeforePause = product.library.revision
                product.library.enabled = false; product.setCapture(false)
                op_cef_test(workspace.active!.browser, 1)
                try await Task.sleep(for: .seconds(2))
                try check(product.library.revision == revisionBeforePause, "paused Chromium contexts do not write mutated DOM snapshots")
                try check(!product.library.enabled, "capture pause propagated to all windows")
                product.library.enabled = true; product.setCapture(true)
                let stream = workspace.active!
                op_cef_test(stream.browser, 1)
                try await wait("streaming") { (await self.product.library.messages(self.a)).first?.lastObservation == .streaming }
                try check((await product.library.messages(a)).first?.state != .complete, "stream never promoted to complete")
                op_cef_test(stream.browser, 9)
                try await wait("renderer crash") { stream.pageState == .interrupted }
                try check(scene.window?.isVisible == true, "renderer crash preserves native window")
                try check((await product.library.messages(a)).first?.body.hasPrefix("Synthetic protected response") == true, "renderer crash preserves prior protected body")
                scene.reload()
                try await wait("renderer retry") { stream.readableConversation == self.a }
                try check(stream.observerAvailable, "renderer retry retains isolated observer installation")
                let streamingID = "77777777-7777-4777-8777-777777777777"
                try JSONSerialization.data(withJSONObject: [streamingID: "stream", a: "normal"]).write(to: root.appendingPathComponent("mode.json"), options: .atomic)
                product.openWindow(url: CEFIdentity.url(summary(streamingID)))
                try await wait("new incomplete reply") { (await self.product.library.messages(streamingID)).first?.state == .streaming }
                try check((await product.library.messages(streamingID)).first?.state == .streaming, "new incomplete reply stored as streaming")
                await product.windows.last!.workspace.close()
                try await wait("stream interruption") { (await self.product.library.messages(streamingID)).first?.state == .interrupted }
                try check((await product.library.messages(streamingID)).first?.state == .interrupted, "closing an unfinished stream marks it interrupted")
                try mode("normal")
                try await runExecutionQuery()
                try await runReplyNotifications()
                try await runTransportDiagnostics()
            }
            let elapsed = began.duration(to: .now).components
            metrics["suiteSeconds"] = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
            try output(status: "PASS", error: nil, restart: restart)
        } catch { try? output(status: "FAIL", error: error.localizedDescription, restart: restart) }
        product.quit()
    }
    func output(status: String, error: String?, restart: Bool) throws {
        var object: [String: Any] = ["status": status, "checks": checks, "metrics": metrics]
        if let error { object["error"] = error }
        try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]).write(to: root.appendingPathComponent(restart ? "restart.json" : "core.json"), options: .atomic)
    }
}

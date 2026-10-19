import AppKit
import SwiftUI
import WebKit
import Darwin

private let initialConversation = ProcessInfo.processInfo.environment["OP_TEST_CONVERSATION_ID"] ?? ""

@MainActor
final class PerformanceDelegate: NSObject, NSApplicationDelegate {
    var windows: [NSWindow] = []
    var workspaces: [BrowserWorkspace] = []
    var prepareSession: BrowserSession?
    let args = CommandLine.arguments
    var directory: URL { URL(fileURLWithPath: args[2]) }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let menu = NSMenu()
        let app = NSMenuItem(); let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Performance Tests", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        app.submenu = appMenu; menu.addItem(app)
        let file = NSMenuItem(title: "File", action: nil, keyEquivalent: ""); let fileMenu = NSMenu()
        let new = NSMenuItem(title: "New synthetic chat", action: #selector(newChat), keyEquivalent: "o")
        new.keyEquivalentModifierMask = [.command, .shift]; new.target = self
        fileMenu.addItem(new); file.submenu = fileMenu; menu.addItem(file); NSApp.mainMenu = menu
        Task {
            do { if args[1] == "prepare" { try await prepare() } else { try await measure() } }
            catch { write(["status":"BLOCKED", "reason":error.localizedDescription], name:"results.json"); if args[1] != "prepare" { NSApp.terminate(nil) } }
        }
    }
    @objc func newChat() { prepareSession?.webView.newChat() }
    func write(_ value: Any, name: String) {
        if let data = try? JSONSerialization.data(withJSONObject:value,options:[.prettyPrinted,.sortedKeys]) {
            try? data.write(to:directory.appendingPathComponent(name),options:.atomic)
        }
    }
    func wait(_ description: String, seconds: Int = 45, until ready: () async throws -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by:.seconds(seconds))
        while ContinuousClock.now < deadline {
            if try await ready() { return }
            try await Task.sleep(for:.milliseconds(25))
        }
        throw NSError(domain:"PerformanceTests",code:1,userInfo:[NSLocalizedDescriptionKey:"Timed out: " + description])
    }
    func makeWindow() -> NSWindow {
        let w = NSWindow(contentRect:NSRect(x:100 + windows.count*30,y:100,width:1100,height:780),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        w.title = "OP — Synthetic Cache Performance"; w.isReleasedWhenClosed = false
        windows.append(w); w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
        return w
    }
    func library() throws -> SnapshotLibrary {
        SnapshotLibrary(store:try SnapshotStore(url:directory.appendingPathComponent("snapshots.sqlite")),preferences:nil)
    }
    func prepare() async throws {
        guard SnapshotIdentity.valid(initialConversation) else {
            throw NSError(domain: "PerformanceTests", code: 3, userInfo: [NSLocalizedDescriptionKey: "Set OP_TEST_CONVERSATION_ID to an independent synthetic conversation UUID"])
        }
        let lib = try library(); let session = BrowserSession(loadHome:false,library:lib)
        prepareSession = session
        let w = makeWindow(); w.contentView = session.webView
        session.startOnce(at:URL(string:"https://chatgpt.com/")!)
        var prepared: [String:String] = ["A":initialConversation]
        for _ in 0..<1800 {
            if let result = try? await session.webView.evaluateJavaScript("""
                (()=>{let label=null; for(const n of document.querySelectorAll('[data-dil-message-id]')) {
                const route=location.pathname.split('/').pop(); if(n.closest('[data-chatgpt-selection-conversation-id]')?.getAttribute('data-chatgpt-selection-conversation-id')!==route)continue; const t=n.innerText?.trim(); if(t==='OP_CACHE_B')label='B'; if(t==='OP_CACHE_C')label='C';}
                return {label,path:location.pathname};})()
                """) as? [String:Any], let label = result["label"] as? String,
               let path = result["path"] as? String, let id = path.split(separator:"/").last.map(String.init), SnapshotIdentity.valid(id) {
                prepared[label] = id
                write(prepared,name:"conversations.json")
            }
            try await Task.sleep(for:.seconds(1))
        }
    }
    func rssKiB() -> Int {
        var info = mach_task_basic_info(); var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size/MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to:&info) { ptr in
            ptr.withMemoryRebound(to:integer_t.self,capacity:Int(count)) { task_info(mach_task_self_,task_flavor_t(MACH_TASK_BASIC_INFO),$0,&count) }
        }
        return result == KERN_SUCCESS ? Int(info.resident_size/1024) : -1
    }
    func milliseconds(_ start: Double) -> Double { (ProcessInfo.processInfo.systemUptime-start)*1000 }
    func measure() async throws {
        let data = try Data(contentsOf:directory.appendingPathComponent("conversations.json"))
        let ids = try JSONDecoder().decode([String:String].self,from:data)
        guard let a = ids["A"], let b = ids["B"], let c = ids["C"] else { throw CocoaError(.fileReadCorruptFile) }
        guard Set([a,b,c]).count == 3 else {throw CocoaError(.fileReadCorruptFile)}
        let lib = try library()
        let seedRows = try await lib.store!.recent()
        guard Set([a,b,c]).isSubset(of: Set(seedRows.map(\.id))),
              seedRows.allSatisfy({ $0.updatedAt > Date().addingTimeInterval(-3600) && $0.messageCount > 0 })
        else {throw NSError(domain:"PerformanceTests",code:2,userInfo:[NSLocalizedDescriptionKey:"Missing or expired synthetic snapshot seed"])}
        var results: [[String:Any]] = []
        let workspace = BrowserWorkspace(library:lib); workspaces.append(workspace)
        let start = ProcessInfo.processInfo.systemUptime; let loads = BrowserView.totalExplicitLoads
        let window = makeWindow(); window.contentView = NSHostingView(rootView:ContentView(makeWorkspace:{workspace}))
        func sample(_ name:String, target:String, began:Double, loads:Int, attachments:Int, native:Double) async throws -> [String:Any] {
            do {
                try await wait("validated official body for " + name) { workspace.active.readableConversationID == target && workspace.active.matches(target) }
            } catch {
                let metadata = try? await workspace.active.webView.evaluateJavaScript("""
                    ({path:location.pathname,nodes:Array.from(document.querySelectorAll('[data-dil-message-id]')).map(n=>({id:n.getAttribute('data-dil-message-id'),chars:(n.innerText||'').length,unit:n.closest('[data-content-search-unit-key]')?.getAttribute('data-content-search-unit-key'),references:n.closest('[data-chatgpt-search-message-ids]')?.getAttribute('data-chatgpt-search-message-ids'),conversation:n.closest('[data-chatgpt-selection-conversation-id]')?.getAttribute('data-chatgpt-selection-conversation-id'),selection:n.closest('[data-chatgpt-selection-message-id]')?.getAttribute('data-chatgpt-selection-message-id')}))})
                    """)
                write(["status":"BLOCKED","samples":results,"scenario":name,"metadata":metadata ?? [:],"pageState":workspace.active.pageState.rawValue,"httpStatus":workspace.active.lastHTTPStatus ?? 0],name:"blocked-metadata.json")
                throw error
            }
            let official = milliseconds(began)
            try await wait("attached visible body for " + name) {
                guard workspace.active.webView.window != nil, !workspace.active.webView.isHidden else {return false}
                return (try await workspace.active.webView.evaluateJavaScript("""
                    Array.from(document.querySelectorAll('[data-dil-message-id]')).some(n=>{const r=n.getBoundingClientRect();return r.bottom>0&&r.top<innerHeight&&r.width>0&&(n.innerText||'').trim().length>0})
                    """) as? Bool) == true
            }
            window.displayIfNeeded()
            _ = try await workspace.active.webView.takeSnapshot(configuration:nil)
            var row: [String:Any] = ["scenario":name,"nativeSelectionMs":native,"officialBodyObservedMs":official,
                "renderedWebSnapshotReadyMs":milliseconds(began),"explicitLoads":BrowserView.totalExplicitLoads-loads,
                "viewAttachments":BrowserView.totalAttachments-attachments,"rssKiB":rssKiB(),"modalRecovery":workspace.showRecovery,
                "physicalDisplayFirstVisibleMs":NSNull()]
            let attached = workspace.active.webView.lastAttachedAt
            row["lastAttachmentMs"] = attached >= began ? (attached-began)*1000 : 0
            #if CACHE_OPTIMIZED
            row["localHadSavedContent"] = workspace.metrics.events.contains {$0.operation == workspace.metrics.operation && $0.name == "snapshotRestored"}
            row["localViewMs"] = workspace.metrics.events.first(where:{$0.operation==workspace.metrics.operation && $0.name=="localViewAppeared"}).map { ($0.uptime-began)*1000 } ?? NSNull() as Any
            #endif
            return row
        }
        results.append(try await sample("startup",target:a,began:start,loads:loads,attachments:0,native:0))
        workspace.showRecovery = false
        for (name,id) in [("coldB",b),("returnA",a),("coldC",c),("warmB",b),("warmA",a),("warmC",c),("warmA2",a)] {
            let begin=ProcessInfo.processInfo.systemUptime; let l=BrowserView.totalExplicitLoads; let attachments=BrowserView.totalAttachments
            workspace.open(ConversationSummary(id:id,updatedAt:Date(),messageCount:1))
            let native = milliseconds(begin)
            results.append(try await sample(name,target:id,began:begin,loads:l,attachments:attachments,native:native))
            write(["status":"RUNNING","samples":results],name:"results.json")
        }
        let second = BrowserWorkspace(library:lib); workspaces.append(second)
        let secondWindow = makeWindow(); secondWindow.contentView = NSHostingView(rootView:ContentView(makeWorkspace:{second}))
        try await wait("second window starts") {second.active.navigationStarts>0}
        second.open(ConversationSummary(id:a,updatedAt:Date(),messageCount:1))
        try await wait("second window official") {second.active.readableConversationID==a}
        let switchStart=ProcessInfo.processInfo.systemUptime
        window.makeKeyAndOrderFront(nil); window.displayIfNeeded()
        _ = try await workspace.active.webView.takeSnapshot(configuration:nil)
        results.append(["scenario":"multiWindowReturn","renderedWebSnapshotReadyMs":milliseconds(switchStart),"rssKiB":rssKiB(),"separateWebViews":second.active.webView !== workspace.active.webView,"snapshotAvailable":true])
        #if CACHE_OPTIMIZED
        workspace.trimInactiveSessions()
        results.append(["scenario":"pressureTrim","retained":workspace.sessions.count,"rssKiB":rssKiB()])
        #endif
        write(["status":"PASS","samples":results,"rssIsAppOnly":true,"physicalDisplayLatencyUnavailable":true],name:"results.json")
        for w in workspaces {w.close()}
        NSApp.terminate(nil)
    }
}

@main struct PerformanceMain {
    @MainActor static func main() {
        let app=NSApplication.shared; let delegate=PerformanceDelegate(); app.delegate=delegate; app.run()
    }
}

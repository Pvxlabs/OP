import AppKit
import WebKit
import SwiftUI

private let ids = ["11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222", "33333333-3333-4333-8333-333333333333"]
private let official = (ProcessInfo.processInfo.environment["OP_TEST_CONVERSATION_IDS"] ?? "").split(separator: ",").map(String.init)
@MainActor final class EmbeddingFixture: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        let source = try! String(contentsOf: Bundle.main.url(forResource:"scroll-embedding",withExtension:"html")!,encoding:.utf8)
        let html = source.replacingOccurrences(of:ids[0],with:task.request.url!.lastPathComponent)
        let data = Data(html.utf8)
        task.didReceive(URLResponse(url:task.request.url!,mimeType:"text/html",expectedContentLength:data.count,textEncodingName:"utf-8"))
        task.didReceive(data);task.didFinish()
    }
    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}
}
@MainActor final class EmbeddingRunner: NSObject, NSApplicationDelegate {
    let args=CommandLine.arguments
    var output: URL {URL(fileURLWithPath:args[1])}
    var mode:String {args[2]}
    var website:Bool {args.contains("--website")}
    var window:NSWindow!;var workspace:BrowserWorkspace!;var session:BrowserSession!;var library:SnapshotLibrary!
    func write(_ value:Any,_ name:String){if let data=try? JSONSerialization.data(withJSONObject:value,options:[.prettyPrinted,.sortedKeys]){try? data.write(to:output.appendingPathComponent(name),options:.atomic)}}
    func applicationDidFinishLaunching(_ n:Notification){
        NSApp.setActivationPolicy(.regular)
        let menu=NSMenu(),item=NSMenuItem(),sub=NSMenu();sub.addItem(withTitle:"Quit Embedding Validation",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q");item.submenu=sub;menu.addItem(item);NSApp.mainMenu=menu
        Task {do{try await run()}catch{write(["status":"BLOCKED","error":error.localizedDescription,"httpStatus":session?.lastHTTPStatus ?? 0],"results.json");NSApp.terminate(nil)}}
        Task {try? await Task.sleep(for:.seconds(240));write(["status":"BLOCKED","reason":"wall-clock timeout"],"timeout.json");NSApp.terminate(nil)}
    }
    func wait(_ description:String,seconds:Double=45,_ predicate:() async throws->Bool) async throws {
        let end=ProcessInfo.processInfo.systemUptime+seconds
        while ProcessInfo.processInfo.systemUptime<end{if try await predicate(){return};try await Task.sleep(for:.milliseconds(100))}
        throw NSError(domain:"EmbeddingTests",code:1,userInfo:[NSLocalizedDescriptionKey:"Timeout: "+description])
    }
    func makeSession()->BrowserSession{
        let config=WKWebViewConfiguration();config.websiteDataStore = .default();config.setURLSchemeHandler(EmbeddingFixture(),forURLScheme:"snapshot-fixture")
        return BrowserSession(configuration:config,loadHome:false,library:library,allowFixtures:true)
    }
    func run() async throws {
        if website && (official.count != 3 || Set(official).count != 3 || !official.allSatisfy(SnapshotIdentity.valid)) {
            throw NSError(domain: "EmbeddingTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Set OP_TEST_CONVERSATION_IDS to three distinct comma-separated synthetic conversation UUIDs"])
        }
        let targets=website ? official:ids
        func url(_ id:String)->URL{URL(string:website ? "https://chatgpt.com/c/\(id)":"snapshot-fixture://local/c/\(id)")!}
        library=SnapshotLibrary(store:try SnapshotStore(url:output.appendingPathComponent("snapshots.sqlite")),preferences:nil)
        window=NSWindow(contentRect:NSRect(x:80,y:80,width:1100,height:800),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        window.title="OP Embedding Validation — "+mode;window.isReleasedWhenClosed=false
        if mode=="bare"{session=makeSession();window.contentView=session.webView;session.startOnce(at:url(targets[0]))}
        else{
            workspace=BrowserWorkspace(library:library,factory:{[unowned self] in self.makeSession()},conversationURL:{url($0.id)},homeURL:url(targets[0]))
            window.contentView=NSHostingView(rootView:ContentView(makeWorkspace:{[unowned self] in self.workspace}))
            session=workspace.active
        }
        window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
        try await wait("first identified synthetic official body"){self.session.readableConversationID==targets[0]}
        if mode != "bare"{
            for target in [targets[1],targets[2],targets[0]]{
                workspace.open(ConversationSummary(id:target,updatedAt:Date(),messageCount:1));session=workspace.active
                try await wait("cached target "+target){self.session.readableConversationID==target && !self.workspace.showingLocal}
            }
        }
        window.setContentSize(NSSize(width:1100,height:800))
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for:.seconds(1))
        let bodyJS="""
            const nodes=Array.from(document.querySelectorAll('[data-dil-message-id]'));
            const bodies=nodes.filter(n=>n.closest('[data-chatgpt-selection-conversation-id]')?.getAttribute('data-chatgpt-selection-conversation-id')===id).map(n=>(n.innerText||'').trim());
            let h=2166136261;for(const c of bodies.join('\\n'))h=Math.imul(h^c.charCodeAt(0),16777619);
            return {count:bodies.length,characters:bodies.reduce((a,b)=>a+b.length,0),fingerprint:String(h>>>0)};
            """
        var metadata=try await session.webView.callAsyncJavaScript(bodyJS,arguments:["id":targets[0]],in:nil,contentWorld:MessageObserver.world) as? [String:Any] ?? [:]
        // Only scroll position is changed, no CSS, wheel handlers or official UI are injected.
        let setup="""
            let s=document.querySelector('#viewport')||document.scrollingElement;
            if(website){for(let n=document.querySelector('[data-dil-message-id]')?.parentElement;n;n=n.parentElement){if(n.scrollHeight>n.clientHeight+100&&/auto|scroll/.test(getComputedStyle(n).overflowY)){s=n;break;}}}
            globalThis.__embeddingScroller=s;s.scrollTop=s.scrollHeight;
            return {extent:s.scrollHeight-s.clientHeight,viewport:[s.clientWidth,s.clientHeight]};
            """
        metadata["scroll"]=try await session.webView.callAsyncJavaScript(setup,arguments:["website":website],in:nil,contentWorld:MessageObserver.world)
        try await Task.sleep(for:.seconds(3))
        metadata["mode"]=mode;metadata["pid"]=ProcessInfo.processInfo.processIdentifier;metadata["website"]=website
        metadata["readyUTC"]=ISO8601DateFormatter().string(from:Date());metadata["sessionCount"]=workspace?.sessions.count ?? 1
        var visibility:[[String:Any]]=[]
        for s in workspace?.sessions ?? [session!]{
            let state=try await s.webView.evaluateJavaScript("({hidden:document.hidden,visibility:document.visibilityState})")
            visibility.append(["active":s===session,"mounted":s.webView.window != nil,"state":state ?? [:]])
        }
        metadata["visibility"]=visibility;write(metadata,"ready.json")
        try await wait("measurement go file",seconds:180){FileManager.default.fileExists(atPath:self.output.appendingPathComponent("go").path)}
        write(["startUTC":ISO8601DateFormatter().string(from:Date()),"mode":mode],"measurement-start.json")
        let result=try await session.webView.callAsyncJavaScript("""
            const s=globalThis.__embeddingScroller,origin=s.scrollTop,begin=performance.now();let maxGap=0,last=begin,steps=0;
            await new Promise(resolve=>{const timer=setInterval(()=>{const now=performance.now();maxGap=Math.max(maxGap,now-last);last=now;steps++;s.scrollTop=Math.max(0,origin-Math.min(origin,9600)*Math.min(1,(now-begin)/12000));if(now-begin>=12000){clearInterval(timer);resolve();}},16);});
            return {origin,final:s.scrollTop,travel:origin-s.scrollTop,steps,durationMs:performance.now()-begin,timerMaxGapMs:maxGap,physicalDisplayFPS:null};
            """,arguments:[:],in:nil,contentWorld:MessageObserver.world)
        let saved=await library.messages(targets[0]);let bodyAfter=try await session.webView.callAsyncJavaScript(bodyJS,arguments:["id":targets[0]],in:nil,contentWorld:MessageObserver.world)
        write(["status":"PASS","trajectory":result ?? [:],"before":metadata,"after":bodyAfter ?? [:],"savedMessages":saved.count,"endUTC":ISO8601DateFormatter().string(from:Date()),"explicitLoads":(workspace?.sessions ?? [session!]).map{$0.webView.explicitLoads}],"results.json")
        // Keep the exact test window available for completed trace/visible UI checks.
        try await wait("finish file",seconds:60){FileManager.default.fileExists(atPath:self.output.appendingPathComponent("finish").path)}
        if let workspace{workspace.close()}else{session.retire()};NSApp.terminate(nil)
    }
}
@main struct EmbeddingMain {
    @MainActor static func main() {
        // Finder/LaunchServices and UI inspection can reopen without test arguments.
        // Reject that launch before creating any application windows or indexing args.
        guard CommandLine.arguments.count >= 3,
              ["bare", "op"].contains(CommandLine.arguments[2]),
              CommandLine.arguments[1].hasPrefix("/") else {
            FileHandle.standardError.write(Data("Usage: OP Embedding Validation <absolute evidence directory> <bare|op> [--website]\n".utf8))
            return
        }
        let app=NSApplication.shared,delegate=EmbeddingRunner()
        app.delegate=delegate;app.run()
    }
}

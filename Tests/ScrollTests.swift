import AppKit
import WebKit
import SwiftUI

private let conversation = "11111111-1111-4111-8111-111111111111"

@MainActor
final class ScrollFixture: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        let body = (1...140).map { i in
            let id = String(format: "%08d-2222-4222-8222-222222222222", i)
            let paragraphs = (1...16).map { p in "<p>SYNTHETIC_SCROLL_\(i)_\(p) " + String(repeating: "Water cycles through clouds and rivers. 中文合成滚动正文。", count: 6) + "</p>" }.joined()
            return "<article data-talvt-turn-state='complete'><div data-content-search-unit-key='test:assistant' data-chatgpt-search-message-ids='\(id)'><div data-chatgpt-selection-conversation-id='\(conversation)' data-chatgpt-selection-message-id='\(id)'><div data-dil-message-id='\(id)'>\(paragraphs)</div></div></div></article>"
        }.joined()
        let html = "<!doctype html><meta charset=utf-8><title>Synthetic Scroll Validation</title><style>body{font:16px system-ui;line-height:1.5;margin:0}main{max-width:780px;margin:auto}article{padding:18px;border-bottom:1px solid #ddd}header{position:fixed;top:0;background:#fff;padding:5px}</style><header>合成长页面滚动验证 <span id=unrelated-tick>0</span></header><main>\(body)</main>"
        let data = Data(html.utf8)
        task.didReceive(URLResponse(url: task.request.url!, mimeType: "text/html", expectedContentLength: data.count, textEncodingName: "utf-8"))
        task.didReceive(data); task.didFinish()
    }
    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}
}

@MainActor
final class ScrollRunner: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var session: BrowserSession!
    var library: SnapshotLibrary!
    let output = URL(fileURLWithPath: CommandLine.arguments[1])
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let root = NSMenu(); let item = NSMenuItem(); let app = NSMenu()
        app.addItem(withTitle: "Quit Scroll Validation", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = app;root.addItem(item);NSApp.mainMenu=root
        Task {
            do { try await run() }
            catch { write(["status":"BLOCKED","error":error.localizedDescription],name:"results.json");NSApp.terminate(nil) }
        }
    }
    func write(_ object: Any, name: String) {
        if let data = try? JSONSerialization.data(withJSONObject: object,options:[.prettyPrinted,.sortedKeys]) {try? data.write(to:output.appendingPathComponent(name))}
    }
    func run() async throws {
        window=NSWindow(contentRect:NSRect(x:0,y:0,width:1100,height:800),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        window.title="OP Scroll Validation — Synthetic Only";window.isReleasedWhenClosed=false
        window.center();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
        Task { @MainActor in
            try? await Task.sleep(for:.seconds(180))
            write(["status":"BLOCKED","reason":"test host wall-clock timeout; no completed scroll measurement"],name:"timeout.json")
            NSApp.terminate(nil)
        }
        var results:[[String:Any]]=[]
        let website = CommandLine.arguments.contains("--website")
        let liveID = ProcessInfo.processInfo.environment["OP_TEST_CONVERSATION_ID"] ?? ""
        if website && !SnapshotIdentity.valid(liveID) {
            throw NSError(domain: "ScrollTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Set OP_TEST_CONVERSATION_ID to an independent synthetic conversation UUID"])
        }
        for enabled in [false,true] {
            let config=WKWebViewConfiguration();config.setURLSchemeHandler(ScrollFixture(),forURLScheme:"snapshot-fixture")
            library=SnapshotLibrary(store:try SnapshotStore(url:output.appendingPathComponent("scroll-\(enabled).sqlite")),preferences:nil)
            session=BrowserSession(configuration:config,loadHome:false,library:library,observeMessages:enabled,allowFixtures:true)
            window.contentView=session.webView
            session.startOnce(at:URL(string:website ? "https://chatgpt.com/c/\(liveID)" : "snapshot-fixture://local/c/\(conversation)")!)
            for _ in 0..<200 {if session.navigationFinishes>0 {break};try await Task.sleep(for:.milliseconds(50))}
            guard session.navigationFinishes>0 else {throw CocoaError(.fileReadUnknown)}
            var stableMetadata: [String:Any] = [:]
            if website {
                // Public rendered DOM only. Stability means observation quietness, never server completion.
                var previous="",quiet=0
                for _ in 0..<80 {
                    write(["phase":"waitingForStaticDOM","observerEnabled":enabled],name:"progress.json")
                    let value = try await session.webView.callAsyncJavaScript("""
                        const nodes=Array.from(document.querySelectorAll('[data-dil-message-id]'));
                        const accepted=nodes.filter(n=>n.closest('[data-chatgpt-selection-conversation-id]')?.getAttribute('data-chatgpt-selection-conversation-id')===id);
                        const lengths=accepted.map(n=>(n.innerText||'').trim().length);
                        return {available:lengths.some(n=>n>0)&&location.pathname.endsWith('/'+id),messageNodes:accepted.length,bodyCharacters:lengths.reduce((a,b)=>a+b,0),busyNodes:document.querySelectorAll('[data-talvt-turn-state="in_progress"]').length};
                        """,arguments:["id":liveID],in:nil,contentWorld:MessageObserver.world)
                    stableMetadata=value as? [String:Any] ?? [:]
                    let key=String(describing:stableMetadata["bodyCharacters"] ?? "")+":"+String(describing:stableMetadata["messageNodes"] ?? "")
                    if key==previous && stableMetadata["available"] as? Bool == true {quiet+=1}else{quiet=0}
                    if quiet>=6 {stableMetadata["quietMilliseconds"]=3000;break}
                    previous=key;try await Task.sleep(for:.milliseconds(500))
                }
                stableMetadata["available"] = quiet>=6
                guard stableMetadata["available"] as? Bool == true else {
                    write(["status":"BLOCKED","reason":"settled synthetic official conversation body unavailable","httpStatus":session.lastHTTPStatus ?? 0,"samples":results],name:"results.json")
                    NSApp.terminate(nil);return
                }
            } else { try await Task.sleep(for:.seconds(2)) }
            for scenario in (website ? ["scrollOnly"] : ["scrollOnly","unrelatedMutations","replyMutations"]) {
                write(["phase":"measuringBottomUpScroll","observerEnabled":enabled],name:"progress.json")
                let result = try await session.webView.callAsyncJavaScript("""
                    const gaps=[]; let tick=0;
                    let scroller=document.scrollingElement;
                    if(website){ for(let n=document.querySelector('[data-dil-message-id]')?.parentElement;n;n=n.parentElement){
                      if(n.scrollHeight>n.clientHeight+100 && /auto|scroll/.test(getComputedStyle(n).overflowY)){scroller=n;break;}}
                    }
                    const extent=scroller.scrollHeight-scroller.clientHeight;
                    if(website){scroller.scrollTo(0,extent);await new Promise(r=>setTimeout(r,1000));}
                    const origin=scroller.scrollTop;let minY=origin,maxY=origin;
                    let last=performance.now(),start=last;
                    const longTasks=[],longTaskSupported=(globalThis.PerformanceObserver?.supportedEntryTypes||[]).includes('longtask');
                    let taskObserver;if(longTaskSupported){taskObserver=new PerformanceObserver(list=>{for(const e of list.getEntries())longTasks.push({startMs:e.startTime-start,durationMs:e.duration});});taskObserver.observe({type:'longtask'});}

                    globalThis.__scrollCollectMetrics={calls:0,totalMs:0,maxMs:0};
                    globalThis.__scrollMutationMetrics={calls:0,totalMs:0,maxMs:0};
                    await new Promise(resolve=>{function frame(now){gaps.push(now-last);last=now;tick++;
                    const y=website ? Math.max(0,Math.min(extent,origin-(now-start)/4000*Math.min(extent,2800))) : 1000+Math.sin((now-start)/1000)*900;scroller.scrollTo(0,y);minY=Math.min(minY,scroller.scrollTop);maxY=Math.max(maxY,scroller.scrollTop);
                    if(scenario==='unrelatedMutations')document.querySelector('#unrelated-tick').textContent=String(tick);
                    if(scenario==='replyMutations'&&tick%20===0)document.querySelector('[data-dil-message-id] p').textContent+=' extra';
                    if(now-start<4000)requestAnimationFrame(frame);else resolve();}requestAnimationFrame(frame);});
                    const sorted=gaps.slice(2).sort((a,b)=>a-b),pick=p=>sorted[Math.min(sorted.length-1,Math.floor(sorted.length*p))];
                    taskObserver?.disconnect();
                    return {scrollExtent:extent,startScrollTop:origin,scrollTravel:maxY-minY,longTaskSupported,longTasks,mutation:globalThis.__scrollMutationMetrics,frames:sorted.length,medianFrameMs:pick(.5),p95FrameMs:pick(.95),maxFrameMs:pick(1),
                      over33Ms:sorted.filter(x=>x>33.4).length,collect:globalThis.__scrollCollectMetrics};
                    """,arguments:["scenario":scenario,"website":website],in:nil,contentWorld:MessageObserver.world) as? [String:Any] ?? [:]
                var row=result;row["observerEnabled"]=enabled;row["scenario"]=scenario;row["settledDOM"]=stableMetadata;results.append(row)
            }
            let saved=await library.messages(website ? liveID : conversation)
            write(["status":"RUNNING","samples":results,"savedMessages":saved.count],name:"results.json")
            session.retire()
        }
        write(["status":"PASS","samples":results,"measurement":website ? "settled official synthetic conversation, bottom-to-top rAF-driven scroll, not physical trackpad input" : "synthetic rAF-driven scroll, not physical trackpad input"],name:"results.json")
        if CommandLine.arguments.contains("--preview") {
            let config=WKWebViewConfiguration();config.setURLSchemeHandler(ScrollFixture(),forURLScheme:"snapshot-fixture")
            session=BrowserSession(configuration:config,loadHome:false,library:library,allowFixtures:true)
            window.contentView=session.webView
            session.startOnce(at:URL(string:"snapshot-fixture://local/c/\(conversation)")!)
        } else {NSApp.terminate(nil)}
    }
}

@main struct ScrollMain {
    @MainActor static func main() {let app=NSApplication.shared;let runner=ScrollRunner();app.delegate=runner;app.run()}
}

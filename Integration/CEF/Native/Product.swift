import AppKit
import SwiftUI

private let nativeAppName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "OP CEF Integration"

enum ProductAppearance: String, CaseIterable {
    case system, light, dark
    var title: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "夜晚"
        }
    }
    var native: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

// System appearance can change while a window is open, including when the app
// is inactive. Resolve the native chrome together in the view's actual appearance.
private final class TitleAppearanceView: NSView {
    var appearanceChanged: (() -> Void)?
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        appearanceChanged?()
    }
}

@MainActor final class ProductWindow: NSWindowController, NSWindowDelegate {
    let workspace: CEFWorkspace
    let titleLabel = NSTextField(labelWithString: "OP")
    let refreshButton = NSButton()
    let collectButton = NSButton()
    var statusPopover: NSPopover?
    var mayClose = false
    private var standardControlFrames: [(NSButton, NSRect)] = []
    init(library: SnapshotLibrary, url: URL?) {
        workspace = CEFWorkspace(library: library)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 820),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = nativeAppName; window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true; window.toolbarStyle = .unified
        window.titlebarSeparatorStyle = .none
        window.isReleasedWhenClosed = false; window.minSize = NSSize(width: 700, height: 520)
        window.delegate = self
        // Keep system window controls in their native titlebar; a bottom accessory
        // extends its measured 32 pt height to 40 pt without an NSToolbar minimum.
        let accessory = NSTitlebarAccessoryViewController()
        accessory.layoutAttribute = .leading
        let titleArea = TitleAppearanceView(frame: NSRect(x: 0, y: 0, width: 410, height: 32))
        titleArea.appearanceChanged = { [weak self] in self?.updateTitleAppearance() }
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.isBordered = false; titleLabel.isBezeled = false; titleLabel.drawsBackground = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleArea.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: titleArea.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: titleArea.trailingAnchor, constant: -12),
            titleLabel.centerYAnchor.constraint(equalTo: titleArea.centerYAnchor, constant: 2)
        ])
        accessory.view = titleArea
        window.addTitlebarAccessoryViewController(accessory)
        let heightAccessory = NSTitlebarAccessoryViewController()
        heightAccessory.layoutAttribute = .bottom
        heightAccessory.automaticallyAdjustsSize = false
        heightAccessory.view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 8))
        heightAccessory.view.heightAnchor.constraint(equalToConstant: 8).isActive = true
        window.addTitlebarAccessoryViewController(heightAccessory)
        let refreshAccessory = NSTitlebarAccessoryViewController()
        refreshAccessory.layoutAttribute = .trailing
        let refreshArea = NSView(frame: NSRect(x: 0, y: 0, width: 128, height: 32))
        collectButton.title = "收取"
        collectButton.image = NSImage(systemSymbolName: "tray.and.arrow.down", accessibilityDescription: nil)
        collectButton.imagePosition = .imageLeading
        collectButton.isBordered = false
        collectButton.font = .systemFont(ofSize: 12, weight: .semibold)
        collectButton.target = self; collectButton.action = #selector(collectClinx)
        collectButton.toolTip = "收取 CLINX 任务结果"
        collectButton.setAccessibilityLabel("收取 CLINX 任务结果")
        collectButton.translatesAutoresizingMaskIntoConstraints = false
        refreshArea.addSubview(collectButton)
        refreshButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "刷新页面")
        refreshButton.target = self; refreshButton.action = #selector(reload)
        refreshButton.imagePosition = .imageOnly
        refreshButton.isBordered = false
        refreshButton.symbolConfiguration = .init(pointSize: 14, weight: .bold)
        refreshButton.toolTip = "刷新页面 (⌘R)"
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshArea.addSubview(refreshButton)
        NSLayoutConstraint.activate([
            collectButton.leadingAnchor.constraint(equalTo: refreshArea.leadingAnchor, constant: 4),
            collectButton.centerYAnchor.constraint(equalTo: refreshArea.centerYAnchor, constant: 2),
            collectButton.widthAnchor.constraint(equalToConstant: 72),
            collectButton.heightAnchor.constraint(equalToConstant: 28),
            refreshButton.trailingAnchor.constraint(equalTo: refreshArea.trailingAnchor, constant: -10),
            refreshButton.centerYAnchor.constraint(equalTo: refreshArea.centerYAnchor, constant: 2),
            refreshButton.widthAnchor.constraint(equalToConstant: 28),
            refreshButton.heightAnchor.constraint(equalToConstant: 28)
        ])
        refreshAccessory.view = refreshArea
        window.addTitlebarAccessoryViewController(refreshAccessory)
        let hosting = NSHostingView(rootView: ProductView(workspace: workspace))
        // AppKit owns window geometry; local transcript intrinsic sizing must
        // not expand the NSWindow while SwiftUI replaces website/local content.
        hosting.sizingOptions = []
        window.contentView = hosting
        window.center(); if !CommandLine.arguments.contains("--self-test") { window.setFrameAutosaveName("OPCEFIntegrationMain") }
        workspace.titleChanged = { [weak self] in self?.updateTitle() }
        window.makeKeyAndOrderFront(nil)
        window.contentView?.superview?.layoutSubtreeIfNeeded()
        standardControlFrames = [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].compactMap {
            guard let button = window.standardWindowButton($0) else { return nil }
            return (button, button.frame)
        }
        positionStandardControls()
        updateTitleAppearance()
        Task { await workspace.start(url: url) }
    }
    required init?(coder: NSCoder) { fatalError("Not a storyboard controller") }
    func updateTitle() {
        titleLabel.stringValue = workspace.active?.title ?? "OP"
        window?.title = nativeAppName + " — " + titleLabel.stringValue
    }
    func updateTitleAppearance() {
        guard let window else { return }
        let dark = window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        window.backgroundColor = NSColor(white: (dark ? 28.0 : 249.0) / 255, alpha: 1)
        let active = window.isKeyWindow && NSApp.isActive
        titleLabel.textColor = NSColor(white: (dark ? (active ? 238.0 : 174.0) : (active ? 49.0 : 112.0)) / 255, alpha: 1)
        // Avoid accessory-bar vibrancy choosing a light glyph over a light
        // hard-coded background, and keep refresh readable in inactive windows.
        refreshButton.contentTintColor = NSColor(white: (dark ? 238.0 : 49.0) / 255, alpha: 1)
        collectButton.contentTintColor = refreshButton.contentTintColor
    }
    func windowDidBecomeKey(_ notification: Notification) { updateTitleAppearance() }
    func windowDidResignKey(_ notification: Notification) { updateTitleAppearance() }
    private func positionStandardControls() {
        guard window?.styleMask.contains(.fullScreen) == false else { return }
        for (button, original) in standardControlFrames {
            button.setFrameOrigin(original.origin.applying(CGAffineTransform(translationX: 2, y: button.superview?.isFlipped == true ? 2 : -2)))
        }
    }
    func windowDidResize(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in self?.positionStandardControls() }
    }
    func windowDidExitFullScreen(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in self?.positionStandardControls() }
    }
    @objc func goBack() { if let s = workspace.active { op_cef_action(s.browser, 1) } }
    @objc func goForward() { if let s = workspace.active { op_cef_action(s.browser, 2) } }
    @objc func reload() { if let s = workspace.active { s.error = nil; s.readableConversation = nil; op_cef_action(s.browser, 0) } }
    @objc func recover() { workspace.recover() }
    @objc func collectClinx() {
        window?.makeKeyAndOrderFront(nil)
        NativeProduct.shared.openClinxInbox()
        let conversation = workspace.active?.conversation
        Task { await NativeProduct.shared.clinxInbox.refresh(identifyConversation: conversation) }
    }
    @objc func newWindow() { NativeProduct.shared.newWindow() }
    @objc func protection(_ sender: Any?) {
        let popover = NSPopover(); popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: VStack(alignment: .leading, spacing: 14) {
            Text("回复保护").font(.headline)
            Text(workspace.protectionStatus).font(.callout).textSelection(.enabled)
            HStack { Button("查看本地副本") { [weak self] in self?.statusPopover?.close(); self?.recover() }
                Button("重试官方网页") { [weak self] in self?.statusPopover?.close(); self?.reload() } }
        }.padding(20).frame(width: 360))
        popover.contentSize = NSSize(width: 400, height: 500)
        statusPopover = popover
        if let view = window?.contentView {
            let y = view.isFlipped ? view.bounds.minY : view.bounds.maxY
            popover.show(relativeTo: NSRect(x: view.bounds.maxX - 28, y: y, width: 1, height: 1), of: view,
                         preferredEdge: view.isFlipped ? .maxY : .minY)
        }
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if mayClose { return true }
        Task { await workspace.close(); mayClose = true; close(); NativeProduct.shared.remove(self) }
        return false
    }
}

@MainActor final class NativeProduct: NSObject, NSApplicationDelegate {
    static let shared = NativeProduct()
    let library: SnapshotLibrary
    private override init() {
        if CommandLine.arguments.contains("--self-test"), let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--evidence=") }),
           let store = try? SnapshotStore(url: URL(fileURLWithPath: String(arg.dropFirst("--evidence=".count))).appendingPathComponent("test.sqlite")) {
            library = SnapshotLibrary(store: store, preferences: nil)
        } else { library = SnapshotLibrary() }
        super.init()
    }
    var windows: [ProductWindow] = []
    var key: Int64 = 0
    var quitting = false
    var statusItem: NSStatusItem?
    var selfTest: CEFIntegrationTests?
    lazy var clinxInbox = ClinxInbox()
    private var clinxWindow: NSWindowController?
    private(set) var appearance = ProductAppearance(rawValue: UserDefaults.standard.string(forKey: "nativeAppearance") ?? "") ?? .system
    private var appearanceItems: [NSMenuItem] = []
    func nextKey() -> Int64 { key += 1; return key }
    func start() {
        let siteCheck = CommandLine.arguments.first(where: { $0.hasPrefix("--clinx-site-check=") })
            .map { String($0.dropFirst("--clinx-site-check=".count)).lowercased() }
        let siteEvidence = CommandLine.arguments.first(where: { $0.hasPrefix("--evidence=") })
            .map { String($0.dropFirst("--evidence=".count)) }
        NSApp.delegate = self; NSApp.setActivationPolicy(.regular)
        NSApp.appearance = appearance.native
        let menu = NSMenu()
        func submenu(_ name: String) -> NSMenu {
            let root = NSMenuItem(); root.submenu = NSMenu(title: name); menu.addItem(root); return root.submenu!
        }
        func item(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "") {
            let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key); item.target = self
        }
        item(submenu(nativeAppName), "退出 " + nativeAppName, #selector(quit), "q")
        let file = submenu("文件"); item(file, "新窗口", #selector(newWindow), "n"); item(file, "关闭窗口", #selector(closeWindow), "w")
        item(file, "本地回复副本…", #selector(recover), "l")
        let edit = submenu("编辑")
        for (title, action, key) in [("撤销", "undo:", "z"), ("剪切", "cut:", "x"), ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: NSSelectorFromString(action), keyEquivalent: key)
        }
        let page = submenu("页面"); item(page, "刷新", #selector(reload), "r"); item(page, "后退", #selector(back), "["); item(page, "前进", #selector(forward), "]")
        let appearanceMenu = NSMenu(title: "外观")
        let appearanceRoot = NSMenuItem(title: "外观", action: nil, keyEquivalent: "")
        appearanceRoot.submenu = appearanceMenu; page.addItem(appearanceRoot)
        for mode in ProductAppearance.allCases {
            let choice = appearanceMenu.addItem(withTitle: mode.title, action: #selector(selectAppearance(_:)), keyEquivalent: "")
            choice.target = self; choice.representedObject = mode.rawValue
            choice.state = mode == appearance ? .on : .off
            appearanceItems.append(choice)
        }
        item(page, "回复保护状态…", #selector(protection))
        item(page, "CLINX 任务收件箱…", #selector(openClinxInbox))
        item(page, "诊断消息识别（仅元数据）", #selector(diagnose))
        NSApp.mainMenu = menu
        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "circle", accessibilityDescription: "OP CEF Integration")
        let quick = NSMenu(title: nativeAppName)
        item(quick, "新窗口", #selector(newWindow)); item(quick, "本地回复副本…", #selector(recover))
        item(quick, "回复保护状态…", #selector(protection)); quick.addItem(.separator())
        item(quick, "CLINX 任务收件箱…", #selector(openClinxInbox))
        item(quick, "退出 " + nativeAppName, #selector(quit))
        status.menu = quick; statusItem = status
        if CommandLine.arguments.contains("--self-test") {
            let suite = CEFIntegrationTests(product: self); selfTest = suite; Task { await suite.run() }
        } else if let siteCheck, SnapshotIdentity.valid(siteCheck), let siteEvidence, siteEvidence.hasPrefix("/") {
            openWindow(url: URL(string: "https://chatgpt.com/c/" + siteCheck))
            Task { await ClinxSiteCheck.run(product: self, conversation: siteCheck, evidence: URL(fileURLWithPath: siteEvidence)) }
        } else if let argument = CommandLine.arguments.first(where: { $0.hasPrefix("--open-conversation=") }),
                  SnapshotIdentity.valid(String(argument.dropFirst("--open-conversation=".count))) {
            let id = String(argument.dropFirst("--open-conversation=".count)).lowercased()
            openWindow(url: URL(string: "https://chatgpt.com/c/" + id))
        } else {
            let stored = UserDefaults.standard.string(forKey: "cefLastConversation")
            let restore = stored.flatMap { SnapshotIdentity.valid($0) ? URL(string: "https://chatgpt.com/c/" + $0) : nil }
            openWindow(url: restore)
        }
        NSApp.activate(ignoringOtherApps: true)
        if !CommandLine.arguments.contains("--self-test") { clinxInbox.start() }
    }
    @objc func newWindow() { openWindow(url: URL(string: "https://chatgpt.com/")) }
    func openWindow(url: URL?) { let scene = ProductWindow(library: library, url: url); windows.append(scene) }
    var focused: ProductWindow? { (NSApp.keyWindow?.windowController as? ProductWindow) ?? windows.last }
    @objc func closeWindow() { NSApp.keyWindow?.performClose(nil) }
    @objc func recover() { focused?.recover() }
    @objc func reload() { focused?.reload() }
    @objc func back() { focused?.goBack() }
    @objc func forward() { focused?.goForward() }
    @objc func selectAppearance(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String, let mode = ProductAppearance(rawValue: value) else { return }
        setAppearance(mode)
    }
    func setAppearance(_ mode: ProductAppearance) {
        appearance = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "nativeAppearance")
        NSApp.appearance = mode.native
        for item in appearanceItems { item.state = item.representedObject as? String == mode.rawValue ? .on : .off }
        for scene in windows { scene.updateTitleAppearance() }
    }
    @objc func protection() { focused?.protection(nil) }
    @objc func openClinxInbox() {
        let conversation = focused?.workspace.active?.conversation
        if clinxWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 760),
                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "CLINX 任务收件箱"; window.isReleasedWhenClosed = false; window.center()
            window.minSize = NSSize(width: 840, height: 720)
            clinxWindow = NSWindowController(window: window)
        }
        let hosting = NSHostingView(rootView: ClinxInboxView(inbox: clinxInbox, conversation: conversation,
            conversationTitle: focused?.workspace.active?.title) { [weak self] id in
            guard let self else { return }
            if let scene = windows.first(where: { $0.workspace.active?.conversation == id }) { scene.window?.makeKeyAndOrderFront(nil) }
            else { openWindow(url: URL(string: "https://chatgpt.com/c/" + id)) }
        })
        hosting.sizingOptions = []
        clinxWindow?.window?.contentView = hosting
        clinxWindow?.showWindow(nil); clinxWindow?.window?.makeKeyAndOrderFront(nil)
    }
    @objc func diagnose() { if let session = focused?.workspace.active { op_cef_action(session.browser, 4) } }
    @objc func quit() {
        guard !quitting else { return }; quitting = true
        clinxInbox.stop()
        Task { for window in windows { await window.workspace.close() }; op_cef_quit() }
    }
    func remove(_ window: ProductWindow) { windows.removeAll { $0 === window } }
    func setCapture(_ enabled: Bool) { for scene in windows { for s in scene.workspace.sessions { op_cef_enabled(s.browser, enabled) } } }
    func session(_ key: Int64) -> (CEFWorkspace, CEFSession)? {
        for scene in windows { if let s = scene.workspace.sessions.first(where: { $0.id == key }) { return (scene.workspace, s) } }
        return nil
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { if !flag { newWindow() }; return true }
    func applicationDidBecomeActive(_ notification: Notification) { for scene in windows { scene.updateTitleAppearance() } }
    func applicationDidResignActive(_ notification: Notification) { for scene in windows { scene.updateTitleAppearance() } }
}

@_cdecl("op_native_start") @MainActor public func nativeStart() { NativeProduct.shared.start() }
@_cdecl("op_native_quit") @MainActor public func nativeQuit() { NativeProduct.shared.quit() }
@_cdecl("op_native_popup") @MainActor public func nativePopup(_ pointer: UnsafePointer<CChar>) {
    guard let url = URL(string: String(cString: pointer)), url.scheme == "https" else { return }
    NativeProduct.shared.openWindow(url: url)
}
@_cdecl("op_native_event") @MainActor public func nativeEvent(_ key: Int64, _ browser: Int32, _ event: UnsafePointer<CChar>, _ value: UnsafePointer<CChar>) {
    guard let (workspace, session) = NativeProduct.shared.session(key) else { return }
    let name = String(cString: event), value = String(cString: value)
    NativeProduct.shared.selfTest?.event(name, browser: browser, value: value)
    switch name {
    case "clinxDelivery": session.deliveryResult(value)
    case "diagnostic":
        if let raw = value.data(using: .utf8), var object = (try? JSONSerialization.jsonObject(with: raw)) as? [String: Any] {
            if let window = NativeProduct.shared.focused?.window {
                object["nativeTitlebarPoints"] = window.frame.height - window.contentLayoutRect.height
                if let color = window.backgroundColor.usingColorSpace(.sRGB) {
                    object["nativeBackgroundRGB"] = [color.redComponent, color.greenComponent, color.blueComponent].map { Int(($0 * 255).rounded()) }
                }
            }
            guard let data = try? JSONSerialization.data(withJSONObject: object) else { return }
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent((Bundle.main.bundleIdentifier ?? "local.personal.OP.CEFIntegration") + "/Diagnostics")
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let file = directory.appendingPathComponent("message-metadata.json")
            try? data.write(to: file, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        }
    case "flushed": session.flushCount += 1
    case "created": session.browser = browser
    case "title": session.title = value
    case "address":
        if let url = URL(string: value) {
            if CEFIdentity.conversation(url) != session.conversation { session.readableConversation = nil; session.documentID = nil; session.sequence = 0; session.pageState = .unavailable }
            session.url = url
            if let identity = SnapshotIdentity.conversation(in: url), workspace.active === session,
               NativeProduct.shared.focused?.workspace === workspace {
                UserDefaults.standard.set(identity, forKey: "cefLastConversation")
            }
        }
    case "navigation":
        let flags = Array(value); if flags.count == 3 { session.loading = flags[0] == "1"; session.canGoBack = flags[1] == "1"; session.canGoForward = flags[2] == "1" }
    case "bridgeIsolation": session.mainWorldIsolated = value == "true"
    case "observerInstalled": session.observerAvailable = true
    case "observerFailed", "bridgeRejected": session.observerAvailable = false; session.error = "本地消息观察不可用，已保存副本保留"
    case "http":
        session.lastHTTPStatus = Int(value)
        if let status = Int(value), status >= 400 { session.pageState = .readFailure; session.error = "官方网页读取失败（HTTP \(status)）"; session.readableConversation = nil }
    case "loadError", "rendererTerminated":
        session.pageState = .interrupted; session.readableConversation = nil; session.error = "网页进程或加载中断，可从保护状态重试"
        workspace.library.interrupt(session.conversation)
        if name == "rendererTerminated" { session.observerAvailable = false }
    default: break
    }
    workspace.titleChanged?()
}
@_cdecl("op_native_snapshot") @MainActor public func nativeSnapshot(_ key: Int64, _ browser: Int32, _ context: Int32, _ request: Int32, _ urlPointer: UnsafePointer<CChar>, _ json: UnsafePointer<CChar>) {
    guard let (workspace, session) = NativeProduct.shared.session(key),
          let url = URL(string: String(cString: urlPointer)), let identity = CEFIdentity.conversation(url),
          let batch = try? JSONDecoder().decode(ObservedConversation.self, from: Data(String(cString: json).utf8)),
          batch.conversationID == identity, session.conversation == identity else {
        op_cef_ack(browser, context, request, false); return
    }
    Task { let accepted = await workspace.receive(batch, session: session, browser: browser); op_cef_ack(browser, context, request, accepted) }
}

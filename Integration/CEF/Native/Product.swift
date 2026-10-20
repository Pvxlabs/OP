import AppKit
import CoreText
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
    var layoutChanged: (() -> Void)?
    override func layout() {
        super.layout()
        layoutChanged?()
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        appearanceChanged?()
    }
}

// A bordered NSButton ignores contentTintColor. Keep its normal input and
// accessibility behavior, and draw only the hover surface behind a borderless icon.
private final class HeaderButton: NSButton {
    // Accessory button alignment insets otherwise enlarge the actual frame
    // beyond its constrained size, letting the hover surface reach the bar edge.
    override var alignmentRectInsets: NSEdgeInsets { .init(top: 0, left: 0, bottom: 0, right: 0) }
    private var hoverArea: NSTrackingArea?
    private var hovering = false
    var dark = false { didSet { needsDisplay = true } }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area); hoverArea = area
    }
    override func mouseEntered(with event: NSEvent) { hovering = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovering = false; needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        let surface = NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        surface.addClip()
        if isEnabled && (hovering || isHighlighted) {
            (dark ? NSColor(white: 46.0 / 255, alpha: 1) : NSColor.labelColor.withAlphaComponent(isHighlighted ? 0.16 : 0.08)).setFill()
            surface.fill()
        }
        super.draw(dirtyRect)
    }
}

@MainActor final class ProductWindow: NSWindowController, NSWindowDelegate {
    private static let headerFont: NSFont = {
        let url = Bundle.main.url(forResource: "Inter-Bold", withExtension: "otf", subdirectory: "Header")!
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        return NSFont(name: "Inter-Bold", size: 13)!
    }()
    let workspace: CEFWorkspace
    let titleLabel = NSTextField(labelWithString: "OP")
    let refreshButton: NSButton = HeaderButton()
    let collectButton: NSButton = HeaderButton()
    private(set) var queryReport: ExecutionQueryReport?
    var statusPopover: NSPopover?
    var mayClose = false
    private var standardControlFrames: [(NSButton, NSRect)] = []
    private var titleLeading: NSLayoutConstraint!
    private var titleBaseline: NSLayoutConstraint!
    private var buttonTops: [NSLayoutConstraint] = []
    private var refreshTrailing: NSLayoutConstraint!
    private var headerImages: [String: NSImage] = [:]
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
        // Keep system controls and the 40 pt titlebar in native AppKit.
        let accessory = NSTitlebarAccessoryViewController()
        accessory.layoutAttribute = .leading
        let titleArea = TitleAppearanceView(frame: NSRect(x: 0, y: 0, width: 410, height: 40))
        titleArea.appearanceChanged = { [weak self] in self?.updateTitleAppearance() }
        titleArea.layoutChanged = { [weak self] in self?.positionStandardControls() }
        titleLabel.font = Self.headerFont
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.isBordered = false; titleLabel.isBezeled = false; titleLabel.drawsBackground = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleArea.addSubview(titleLabel)
        titleLeading = titleLabel.leadingAnchor.constraint(equalTo: titleArea.leadingAnchor, constant: 17)
        titleBaseline = titleLabel.firstBaselineAnchor.constraint(equalTo: titleArea.topAnchor, constant: 24.727)
        NSLayoutConstraint.activate([
            titleLeading,
            titleLabel.trailingAnchor.constraint(equalTo: titleArea.trailingAnchor, constant: -12),
            titleBaseline
        ])
        accessory.view = titleArea
        window.addTitlebarAccessoryViewController(accessory)
        // Leading/trailing accessories are laid out in AppKit's 32 pt row.
        // Extend the native titlebar to the design's 40 pt height below that row.
        let heightAccessory = NSTitlebarAccessoryViewController()
        heightAccessory.layoutAttribute = .bottom
        heightAccessory.automaticallyAdjustsSize = false
        heightAccessory.view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 8))
        heightAccessory.view.heightAnchor.constraint(equalToConstant: 8).isActive = true
        window.addTitlebarAccessoryViewController(heightAccessory)
        let refreshAccessory = NSTitlebarAccessoryViewController()
        refreshAccessory.layoutAttribute = .trailing
        let refreshArea = NSView(frame: NSRect(x: 0, y: 0, width: 84, height: 40))
        for name in ["CollectDark", "CollectLight", "RefreshDark", "RefreshLight"] {
            let image = NSImage(contentsOf: Bundle.main.url(forResource: name, withExtension: "pdf", subdirectory: "Header")!)!
            image.isTemplate = true
            headerImages[name] = image
        }
        collectButton.target = self; collectButton.action = #selector(queryExecution)
        collectButton.toolTip = "在当前对话查询 CLINX 执行情况"
        collectButton.setAccessibilityLabel("在当前对话查询 CLINX 执行情况")
        collectButton.translatesAutoresizingMaskIntoConstraints = false
        refreshArea.addSubview(collectButton)
        refreshButton.setAccessibilityLabel("刷新页面")
        refreshButton.target = self; refreshButton.action = #selector(reload)
        refreshButton.toolTip = "刷新页面 (⌘R)"
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshArea.addSubview(refreshButton)
        for button in [collectButton, refreshButton] {
            button.title = ""
            button.imagePosition = .imageOnly
            button.bezelStyle = .accessoryBarAction
            button.isBordered = false
            (button.cell as? NSButtonCell)?.highlightsBy = []
        }
        buttonTops = [collectButton, refreshButton].map { $0.topAnchor.constraint(equalTo: refreshArea.topAnchor, constant: 5.002) }
        refreshTrailing = refreshButton.trailingAnchor.constraint(equalTo: refreshArea.trailingAnchor, constant: -12)
        NSLayoutConstraint.activate([
            collectButton.leadingAnchor.constraint(equalTo: refreshArea.leadingAnchor, constant: 4),
            collectButton.widthAnchor.constraint(equalToConstant: 32),
            collectButton.heightAnchor.constraint(equalToConstant: 30),
            refreshTrailing,
            refreshButton.widthAnchor.constraint(equalToConstant: 32),
            refreshButton.heightAnchor.constraint(equalToConstant: 30)
        ] + buttonTops)
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
        // The trailing accessory's clip view remains 32 pt tall even though
        // the titlebar is 40 pt. Allow the designed hover surface through it.
        refreshArea.superview?.clipsToBounds = false
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
        // Both appearances use the approved night layout, glyphs and inactive behavior.
        titleLabel.textColor = dark && active
            ? NSColor(srgbRed: 161.0 / 255, green: 161.0 / 255, blue: 170.0 / 255, alpha: 1)
            : NSColor(white: (active ? 49.0 : 110.0) / 255, alpha: 1)
        collectButton.image = headerImages["CollectDark"]
        refreshButton.image = headerImages["RefreshDark"]
        for button in [collectButton, refreshButton] {
            button.contentTintColor = titleLabel.textColor
            button.isHidden = !active
            (button as? HeaderButton)?.dark = dark
        }
        positionStandardControls()
        DispatchQueue.main.async { [weak self] in self?.positionStandardControls() }
    }
    func windowDidBecomeKey(_ notification: Notification) { updateTitleAppearance() }
    func windowDidResignKey(_ notification: Notification) { updateTitleAppearance() }
    private func positionStandardControls() {
        guard window?.styleMask.contains(.fullScreen) == false else { return }
        guard let window else { return }
        for (index, entry) in standardControlFrames.enumerated() {
            let (button, _) = entry
            guard let parent = button.superview else { continue }
            let center = parent.convert(NSPoint(x: 18.5 + CGFloat(index) * 23,
                y: window.frame.height - 19.5), from: nil)
            button.setFrameOrigin(NSPoint(x: center.x - button.frame.width / 2, y: center.y - button.frame.height / 2))
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
    @objc func queryExecution() {
        guard collectButton.isEnabled else { return }
        guard !workspace.showRecovery, let session = workspace.active else {
            showQueryFailure("请先打开要查询的 ChatGPT 对话。")
            return
        }
        queryReport = nil
        collectButton.isEnabled = false
        collectButton.toolTip = "正在发送查询…"
        Task { [weak self] in
            let report = await session.queryExecution()
            guard let self else { return }
            queryReport = report
            collectButton.isEnabled = true
            collectButton.toolTip = report.status == "sent" ? "查询已发送；再次点击可重新查询执行情况" : report.reason
            if report.status != "sent" { showQueryFailure(report.reason) }
        }
    }
    private func showQueryFailure(_ reason: String) {
        guard let window else { return }
        let alert = NSAlert()
        alert.messageText = "查询未确认发送"
        alert.informativeText = reason
        alert.addButton(withTitle: "好")
        alert.beginSheetModal(for: window)
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
    var replyNotifications = ReplyNotifications()
    lazy var consultations = ConsultationBridge(product: self)
    private(set) var appearance = ProductAppearance(rawValue: UserDefaults.standard.string(forKey: "nativeAppearance") ?? "") ?? .system
    private var appearanceItems: [NSMenuItem] = []
    func nextKey() -> Int64 { key += 1; return key }
    func start() {
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
        item(page, "查询 CLINX 执行情况", #selector(queryExecution))
        item(page, "连接 CLINX 咨询 MCP…", #selector(configureConsultations))
        item(page, "绑定当前 ChatGPT 对话…", #selector(bindConsultation))
        item(page, "咨询桥接状态…", #selector(consultationStatus))
        let notifications = page.addItem(withTitle: "后台回复完成提醒", action: #selector(toggleReplyNotifications(_:)), keyEquivalent: "")
        notifications.target = self; notifications.state = replyNotifications.enabled ? .on : .off
        item(page, "诊断消息识别（仅元数据）", #selector(diagnose))
        NSApp.mainMenu = menu
        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "circle", accessibilityDescription: "OP CEF Integration")
        let quick = NSMenu(title: nativeAppName)
        item(quick, "新窗口", #selector(newWindow)); item(quick, "本地回复副本…", #selector(recover))
        item(quick, "回复保护状态…", #selector(protection)); quick.addItem(.separator())
        item(quick, "查询 CLINX 执行情况", #selector(queryExecution))
        item(quick, "退出 " + nativeAppName, #selector(quit))
        status.menu = quick; statusItem = status
        if CommandLine.arguments.contains("--self-test") {
            let suite = CEFIntegrationTests(product: self); selfTest = suite; Task { await suite.run() }
        } else if let argument = CommandLine.arguments.first(where: { $0.hasPrefix("--open-conversation=") }),
                  SnapshotIdentity.valid(String(argument.dropFirst("--open-conversation=".count))) {
            let id = String(argument.dropFirst("--open-conversation=".count)).lowercased()
            openWindow(url: CEFIdentity.url(.init(id: id, updatedAt: Date(), messageCount: 0)))
        } else {
            let stored = UserDefaults.standard.string(forKey: "cefLastConversation")
            let restore = stored.flatMap { SnapshotIdentity.valid($0) ? URL(string: "https://chatgpt.com/c/" + $0) : nil }
            openWindow(url: restore)
        }
        NSApp.activate(ignoringOtherApps: true)
        replyNotifications.start()
        if !CommandLine.arguments.contains("--self-test") { _ = consultations }
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
    @objc func queryExecution() { focused?.queryExecution() }
    @objc func configureConsultations() { consultations.configure() }
    @objc func bindConsultation() { consultations.bindCurrent() }
    @objc func consultationStatus() { consultations.showStatus() }
    @objc func toggleReplyNotifications(_ sender: NSMenuItem) {
        replyNotifications.enabled.toggle()
        UserDefaults.standard.set(replyNotifications.enabled, forKey: "replyNotificationsEnabled")
        sender.state = replyNotifications.enabled ? .on : .off
        if replyNotifications.enabled { replyNotifications.requestPermission() }
    }
    @objc func diagnose() { if let session = focused?.workspace.active { op_cef_action(session.browser, 4) } }
    @objc func quit() {
        guard !quitting else { return }; quitting = true
        consultations.stop()
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
    let name = String(cString: event), value = String(cString: value)
    if name == "closed" { NativeProduct.shared.replyNotifications.forget(key) }
    guard let (workspace, session) = NativeProduct.shared.session(key) else { return }
    NativeProduct.shared.selfTest?.event(name, browser: browser, value: value)
    switch name {
    case "replyEnded": NativeProduct.shared.replyNotifications.receive(value, session: session)
    case "executionQuery": session.queryResult(value)
    case "transport":
        if let object = try? JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any],
           let status = object["http"] as? Int, [403, 429].contains(status) {
            session.consultationHTTPFailure = status
            session.consultationHTTPChallenge = object["challenge"] as? Bool == true
            session.error = session.consultationHTTPChallenge
                ? "Cloudflare 浏览器验证未完成（HTTP \(status)），交接暂停，请在官方页面完成验证。"
                : "官方网页请求失败（HTTP \(status)），交接暂停"
        }
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
        if let status = Int(value), (200..<300).contains(status) {
            session.consultationHTTPFailure = nil; session.consultationHTTPChallenge = false
        }
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

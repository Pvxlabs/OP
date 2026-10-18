import SwiftUI
import AppKit
import UserNotifications

@main
struct ChatGPTNativeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        WindowGroup("ChatGPT Native", id: "chat") { ContentView() }
            .defaultSize(width: 1180, height: 820)
            .commands { BrowserCommands() }
        MenuBarExtra("ChatGPT Native", systemImage: "bubble.left.and.bubble.right") { QuickLaunchMenu() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        UNUserNotificationCenter.current().delegate = Notifications.shared
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

struct QuickLaunchMenu: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Open ChatGPT") {
            if let window = NSApp.windows.first(where: { $0.canBecomeKey && $0.title == "ChatGPT Native" }) {
                window.deminiaturize(nil)
                window.makeKeyAndOrderFront(nil)
            } else { openWindow(id: "chat") }
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("New Window") { openWindow(id: "chat"); NSApp.activate(ignoringOtherApps: true) }
        Divider()
        Button("Quit ChatGPT Native") { NSApp.terminate(nil) }
    }
}

struct BrowserCommands: Commands {
    @FocusedValue(\.browserWorkspace) private var workspace
    private func send(_ action: Selector) { NSApp.sendAction(action, to: nil, from: nil) }
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Chat") { send(#selector(BrowserView.newChat)) }
                .keyboardShortcut("o", modifiers: [.command, .shift])
        }
        CommandMenu("Page") {
            Button("Reload Page") { send(#selector(BrowserView.reloadPage)) }.keyboardShortcut("r")
            Button("Back") { send(#selector(BrowserView.backPage)) }.keyboardShortcut("[")
            Button("Forward") { send(#selector(BrowserView.forwardPage)) }.keyboardShortcut("]")
            Divider()
            Button("Zoom In") { send(#selector(BrowserView.zoomIn)) }.keyboardShortcut("+")
            Button("Zoom Out") { send(#selector(BrowserView.zoomOut)) }.keyboardShortcut("-")
            Button("Actual Size") { send(#selector(BrowserView.resetZoom)) }.keyboardShortcut("0")
            Divider()
            Button("Enable Download Notifications…") { Notifications.requestPermission() }
        }
        CommandMenu("本地副本") {
            Button("查看保护状态…") { workspace?.showProtectionStatus = true }
                .disabled(workspace == nil)
            Button("查看本地回复…") { workspace?.recover() }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .disabled(workspace == nil)
            if let workspace {
                Toggle("保存本地快照", isOn: Binding(get: { workspace.library.enabled }, set: { workspace.library.enabled = $0 }))
                Divider()
                ForEach(workspace.library.recent.prefix(12)) { item in
                    Button(item.label) { workspace.open(item) }
                }
            }
        }
    }
}

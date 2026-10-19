import SwiftUI

struct ContentView: View {
    @State private var workspace: BrowserWorkspace?
    @State private var dismissedNotice: String?
    private let makeWorkspace: @MainActor () -> BrowserWorkspace
    init(makeWorkspace: @escaping @MainActor () -> BrowserWorkspace = { BrowserWorkspace() }) {
        self.makeWorkspace = makeWorkspace
        _workspace = State(initialValue: nil)
    }

    var body: some View {
        Group {
            if let workspace { browser(workspace).onDisappear { workspace.close() } }
            else { ProgressView("正在恢复本地会话…").frame(minWidth: 640, minHeight: 480) }
        }
        .task {
            // State value initializers can run for discarded View values. Create WebViews
            // only after this window is mounted, not during SwiftUI value reconstruction.
            if workspace == nil { workspace = makeWorkspace() }
            await workspace?.start()
        }
    }

    @ViewBuilder
    private func browser(_ workspace: BrowserWorkspace) -> some View {
        @Bindable var workspace = workspace
        BrowserDeck(workspace: workspace)
            .frame(minWidth: 640, minHeight: 480)
            .overlay(alignment: .top) {
                if let message = recoveryNotice(workspace) {
                    let key = workspace.active.id.uuidString + "|" + (workspace.active.conversationID ?? "") + "|" +
                        String(workspace.active.navigationStarts) + "|" + message
                    if dismissedNotice != key {
                        RecoveryNotice(message: message,
                            retry: { workspace.active.webView.reload() },
                            recover: { workspace.recover() },
                            dismiss: { dismissedNotice = key })
                            .padding(.horizontal, 20).padding(.top, 16)
                    }
                }
            }
            .overlay {
                if workspace.showingLocal {
                    LocalConversationView(workspace: workspace)
                        .id(workspace.localConversation)
                }
            }
            .onChange(of: workspace.library.clearEpoch) { _, _ in workspace.revealOfficial() }
            .focusedSceneValue(\.browserWorkspace, workspace)
            .alert("本地保护状态", isPresented: $workspace.showProtectionStatus) {
                Button("关闭", role: .cancel) {}
                Button("查看本地副本") { workspace.recover() }
            } message: {
                Text(workspace.protectionStatus)
            }
            .sheet(isPresented: $workspace.showRecovery) {
                RecoveryView(library: workspace.library, conversationID: $workspace.recoveryConversation,
                             openOfficial: { workspace.open($0) })
            }
    }

    private func recoveryNotice(_ workspace: BrowserWorkspace) -> String? {
        if let error = workspace.active.error ?? workspace.library.warning { return error }
        if workspace.active.pageState == .readFailure || workspace.active.pageState == .interrupted {
            return "官方内容暂不可读，已保存的回复仍保留在本机。"
        }
        return nil
    }

}

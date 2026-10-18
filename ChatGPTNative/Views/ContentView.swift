import SwiftUI

struct ContentView: View {
    @State private var workspace: BrowserWorkspace?
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
        WebContent(session: workspace.active)
            .id(workspace.active.id)
            .frame(minWidth: 640, minHeight: 480)
            .overlay(alignment: .top) {
                if let error = workspace.active.error ?? workspace.library.warning {
                    HStack {
                        Text(error).font(.callout)
                        Button("Retry") { workspace.active.webView.reload() }
                        Button("本地副本") { workspace.recover() }
                    }
                    .padding().background(.regularMaterial)
                } else if workspace.active.pageState == .readFailure || workspace.active.pageState == .interrupted {
                    Button("官方内容暂不可读 · 查看本地副本") { workspace.recover() }
                        .padding().background(.regularMaterial)
                }
            }
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
}

import SwiftUI
import AppKit

struct ProductView: View {
    @Bindable var workspace: CEFWorkspace
    var body: some View {
        CEFDeck(workspace: workspace)
            .frame(minWidth: 700, minHeight: 480)
            .overlay {
                if workspace.showingLocal {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("本地回复副本", systemImage: "internaldrive").font(.headline)
                            Spacer()
                            Button("查看官方网页") { workspace.revealOfficial() }
                        }
                        Text("后台正在加载官方会话。当前仅显示本机副本，可能不完整，不代表官方分支或服务端终态。")
                            .foregroundStyle(.secondary)
                        if workspace.localLoading { ProgressView() }
                        else if workspace.localMessages.isEmpty { Text("尚无可读取的本地副本，可查看官方网页完成登录或安全验证。") }
                        CachedReplyText(text: RecoveryView.transcript(workspace.localMessages, showAlternatives: false))
                    }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity).background(.background)
                }
            }
            .sheet(isPresented: $workspace.showRecovery) {
                RecoveryView(library: workspace.library, conversationID: $workspace.recoveryID,
                             openOfficial: { workspace.open($0) })
            }
            .onChange(of: workspace.library.enabled) { _, value in NativeProduct.shared.setCapture(value) }
            .onChange(of: workspace.library.clearEpoch) { _, _ in workspace.revealOfficial() }
    }
}

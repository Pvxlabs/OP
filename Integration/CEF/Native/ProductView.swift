import SwiftUI
import AppKit

struct ProductView: View {
    @Bindable var workspace: CEFWorkspace
    var body: some View {
        CEFDeck(workspace: workspace)
            .frame(minWidth: 700, minHeight: 480)
            .sheet(isPresented: $workspace.showRecovery) {
                RecoveryView(library: workspace.library, conversationID: $workspace.recoveryID,
                             openOfficial: { workspace.open($0) })
            }
            .onChange(of: workspace.library.enabled) { _, value in NativeProduct.shared.setCapture(value) }
    }
}

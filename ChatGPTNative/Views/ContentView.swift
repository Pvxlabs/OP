import SwiftUI

struct ContentView: View {
    @State private var session = BrowserSession()

    var body: some View {
        WebContent(session: session)
            .frame(minWidth: 640, minHeight: 480)
            .overlay(alignment: .top) {
                if let error = session.error {
                    HStack {
                        Text(error).font(.callout)
                        Button("Retry") { session.webView.reload() }
                    }
                    .padding().background(.regularMaterial)
                }
            }
    }
}

import SwiftUI

/// Native, dismissible recovery entry. Closing it never clears the underlying error.
struct RecoveryNotice: View {
    let message: String
    let retry: () -> Void
    let recover: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.2.circlepath")
                .font(.system(size: 22, weight: .medium)).foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text("回复保护").font(.system(.subheadline, weight: .semibold))
                    Spacer(minLength: 12)
                    Button(action: dismiss) { Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)) }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .frame(width: 20, height: 20).contentShape(Circle())
                        .accessibilityLabel("关闭提示")
                }
                Text(message).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button("查看本地副本", action: recover)
                    Button("重试", action: retry)
                }.buttonStyle(.bordered).controlSize(.small)
            }
        }
        .padding(16).frame(maxWidth: 400, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.primary.opacity(0.08), lineWidth: 1) }
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
    }
}

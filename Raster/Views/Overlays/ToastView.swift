import SwiftUI

/// Transient confirmation toast (save/export), bottom-centered.
struct ToastView: View {
    let colors: RasterColors
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Text("✓").foregroundStyle(colors.accent)
            Text(message).foregroundStyle(colors.ink)
        }
        .font(.system(size: 12.5))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(colors.panel)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(colors.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

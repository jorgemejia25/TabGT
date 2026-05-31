import SwiftUI

struct GlassTopBar<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 12) {
            content
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(minHeight: 44)
        .background(AppTheme.toolbar.opacity(0.92), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.panelStroke, lineWidth: 1)
        )
        .glassEffect(.regular.interactive(false), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

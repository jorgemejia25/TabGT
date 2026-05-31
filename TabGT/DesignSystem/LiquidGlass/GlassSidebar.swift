import SwiftUI

struct GlassSidebar<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(10)
            .frame(minWidth: 248, idealWidth: 286, maxWidth: 340, maxHeight: .infinity)
            .background(AppTheme.navigator.opacity(0.86), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.panelStroke, lineWidth: 1)
            )
            .glassEffect(.regular.interactive(false), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(8)
    }
}

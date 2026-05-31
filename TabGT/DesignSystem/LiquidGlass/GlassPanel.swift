import SwiftUI

struct GlassPanelModifier: ViewModifier {
    var cornerRadius: CGFloat = 10

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background(AppTheme.panelFill, in: shape)
            .overlay(shape.stroke(AppTheme.panelStroke, lineWidth: 1))
            .glassEffect(.regular.interactive(false), in: shape)
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 10) -> some View {
        modifier(GlassPanelModifier(cornerRadius: cornerRadius))
    }
}

import SwiftUI

struct GlassToolbarButton: View {
    var systemImage: String
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 26)
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plainClickable)
        .foregroundStyle(AppTheme.textPrimary)
        .background(AppTheme.elevatedPanel.opacity(0.65), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(AppTheme.panelStroke, lineWidth: 1)
        )
        .help(title)
    }
}

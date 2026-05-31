import SwiftUI

struct HostRowView: View {
    var host: SSHHost
    var isSelected: Bool
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 8) {
                Image(systemName: "server.rack")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? AppTheme.onSelectionText : AppTheme.textSecondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(host.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? AppTheme.onSelectionText : AppTheme.textPrimary)
                        .lineLimit(1)

                    Text(host.displayAddress)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(isSelected ? AppTheme.onSelectionText.opacity(0.76) : AppTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isSelected ? AppTheme.onSelectionText.opacity(0.62) : AppTheme.textTertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(rowBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isSelected ? AppTheme.selectionBlue.opacity(0.75) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plainClickable)
    }

    private var rowBackground: Color {
        isSelected ? AppTheme.selectionBlue.opacity(0.88) : Color.clear
    }
}

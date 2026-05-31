import SwiftUI

struct SearchField: View {
    @Binding var text: String
    var placeholder: String = "Filter profiles"
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(isFocused ? AppTheme.textSecondary : AppTheme.textTertiary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textPrimary)
                .focused($isFocused)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .buttonStyle(.plainClickable)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(fieldBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(fieldBorder, lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.12), value: isFocused)
    }

    private var fieldBackground: Color {
        isFocused
            ? AppTheme.editor.opacity(0.92)
            : AppTheme.editor.opacity(0.55)
    }

    private var fieldBorder: Color {
        isFocused
            ? AppTheme.selectionBlue.opacity(0.40)
            : AppTheme.panelStroke.opacity(0.45)
    }
}

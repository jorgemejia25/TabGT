import SwiftUI

struct ClipEditorSheet: View {
    @ObservedObject var viewModel: AutomationsViewModel
    @Binding var draft: ClipDraft

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            Divider()
                .overlay(AppTheme.panelStroke)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    editorSection("Clip") {
                        fieldRow("Value") {
                            compactTextField(text: $draft.value, monospaced: true)
                        }

                        fieldRow("Description") {
                            compactTextField(text: $draft.description)
                        }
                    }
                }
                .padding(.vertical, 10)
            }

            Divider()
                .overlay(AppTheme.panelStroke)

            sheetFooter
        }
        .frame(width: 480, height: 260)
        .background(AppTheme.current.windowBackground)
    }

    private var sheetHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray.full")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.selectionBlue)

            VStack(alignment: .leading, spacing: 1) {
                Text("Edit Clip")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Clip Tray")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(AppTheme.toolbar)
    }

    private var sheetFooter: some View {
        HStack(spacing: 8) {
            if draft.isEditing {
                Button("Delete") {
                    viewModel.deleteClipFromEditor()
                    dismiss()
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.danger)
                .buttonStyle(.plainClickable)
            }

            Spacer()

            Button("Cancel") {
                viewModel.dismissClipEditor()
                dismiss()
            }
            .font(.system(size: 12, weight: .medium))
            .buttonStyle(.plainClickable)

            Button("Save Changes") {
                viewModel.saveClipEditorDraft(draft)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.selectionBlue)
            .font(.system(size: 12, weight: .semibold))
            .disabled(!draft.isValid)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(AppTheme.toolbar)
    }

    private func editorSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)

            content()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private func fieldRow<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 126, alignment: .leading)

            content()

            Spacer(minLength: 0)
        }
        .frame(minHeight: 30)
    }

    private func compactTextField(text: Binding<String>, monospaced: Bool = false) -> some View {
        TextField("", text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 12, design: monospaced ? .monospaced : .default))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(AppTheme.editor)
            .overlay(
                Rectangle()
                    .stroke(AppTheme.panelStroke, lineWidth: 1)
            )
    }
}

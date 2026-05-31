import SwiftUI

struct SnippetEditorSheet: View {
    @ObservedObject var viewModel: SnippetsViewModel
    @Binding var draft: SnippetDraft

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            Divider()
                .overlay(AppTheme.panelStroke)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    editorSection("Basics") {
                        if let editorError = viewModel.editorError {
                            Text(editorError)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppTheme.danger)
                                .padding(.bottom, 4)
                        }

                        fieldRow("Title") {
                            compactTextField(text: $draft.title)
                                .onChange(of: draft.title) { _, _ in
                                    viewModel.applyAutomaticTrigger(to: &draft)
                                }
                        }

                        fieldRow("Trigger") {
                            HStack(spacing: 8) {
                                compactTextField(text: $draft.trigger, monospaced: true)
                                    .frame(width: 120)
                                    .onChange(of: draft.trigger) { _, _ in
                                        draft.autoTriggerEnabled = false
                                    }

                                Toggle("Auto", isOn: $draft.autoTriggerEnabled)
                                    .font(.system(size: 11))
                                    .toggleStyle(.checkbox)
                                    .onChange(of: draft.autoTriggerEnabled) { _, enabled in
                                        if enabled {
                                            viewModel.applyAutomaticTrigger(to: &draft)
                                        }
                                    }
                            }
                        }

                        fieldRow("Command") {
                            compactTextField(text: $draft.command, monospaced: true)
                                .onChange(of: draft.command) { _, _ in
                                    viewModel.applyAutomaticTrigger(to: &draft)
                                }
                        }

                        fieldRow("Tags") {
                            compactTextField(text: $draft.tags)
                        }

                        fieldRow("Notes") {
                            compactTextField(text: $draft.notes)
                        }
                    }

                    editorSection("Preview") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Type `\(draft.trigger.isEmpty ? "trigger" : draft.trigger)` in the terminal to expand this command.")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(AppTheme.textSecondary)

                            Text(draft.command.isEmpty ? "command preview" : draft.command)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(AppTheme.textPrimary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
                                .padding(10)
                                .background(TerminalTheme.background)
                                .overlay(
                                    Rectangle()
                                        .stroke(AppTheme.panelStroke, lineWidth: 1)
                                )
                        }
                        .padding(.leading, 138)
                    }
                }
                .padding(.vertical, 10)
            }

            Divider()
                .overlay(AppTheme.panelStroke)

            sheetFooter
        }
        .frame(width: 580, height: 460)
        .background(AppTheme.current.windowBackground)
    }

    private var sheetHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.badge.plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.selectionBlue)

            VStack(alignment: .leading, spacing: 1) {
                Text(draft.isEditing ? "Edit Snippet" : "New Snippet")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Triggers expand as you type in the terminal")
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
            if draft.isEditing, let snippetID = draft.id,
               let snippet = viewModel.snippets.first(where: { $0.id == snippetID }) {
                Button("Delete") {
                    viewModel.deleteSnippet(snippet)
                    dismiss()
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.danger)
                .buttonStyle(.plainClickable)
            }

            Spacer()

            Button("Cancel") {
                viewModel.dismissEditor()
                dismiss()
            }
            .font(.system(size: 12, weight: .medium))
            .buttonStyle(.plainClickable)

            Button(draft.isEditing ? "Save Changes" : "Create Snippet") {
                if viewModel.saveEditorDraft(draft) {
                    dismiss()
                }
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
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.panelStroke)
                .frame(height: 1)
        }
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

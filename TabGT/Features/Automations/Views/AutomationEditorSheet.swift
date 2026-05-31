import SwiftUI

struct AutomationEditorSheet: View {
    @ObservedObject var viewModel: AutomationsViewModel
    @Binding var draft: AutomationDraft

    @Environment(\.dismiss) private var dismiss
    @State private var sampleInput = ""

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            Divider()
                .overlay(AppTheme.panelStroke)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    editorSection("Basics") {
                        fieldRow("Name") {
                            compactTextField(text: $draft.name)
                        }

                        fieldRow("Type") {
                            Picker("", selection: $draft.kind) {
                                ForEach(AutomationKind.allCases) { kind in
                                    Label(kind.label, systemImage: kind.systemImage)
                                        .tag(kind)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(maxWidth: 240, alignment: .leading)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(draft.kind.summary)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(AppTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.leading, 138)

                        fieldRow("Enabled") {
                            Toggle("", isOn: $draft.isEnabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }

                        fieldRow("Notes") {
                            compactTextField(text: $draft.notes)
                        }
                    }

                    editorSection("Trigger") {
                        fieldRow("Watch") {
                            Picker("", selection: $draft.source) {
                                ForEach(AutomationSource.allCases) { source in
                                    Text(source.label).tag(source)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(maxWidth: 240, alignment: .leading)
                        }

                        fieldRow("Trigger") {
                            compactTextField(text: $draft.triggerPattern, monospaced: true)
                        }

                        fieldRow("Case") {
                            Toggle("Case sensitive", isOn: $draft.caseSensitive)
                                .font(.system(size: 12))
                                .toggleStyle(.checkbox)
                        }
                    }

                    editorSection("Capture") {
                        fieldRow("Mode") {
                            Picker("", selection: $draft.captureMode) {
                                ForEach(AutomationCaptureMode.allCases) { mode in
                                    Text(mode.label).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(maxWidth: 240, alignment: .leading)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(draft.captureMode.hint)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(AppTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.leading, 138)

                        if showsExtractPattern {
                            fieldRow("Pattern") {
                                compactTextField(text: $draft.extractPattern, monospaced: true)
                            }
                        }

                        if showsCaptureGroup {
                            fieldRow("Group") {
                                Stepper(
                                    value: $draft.captureGroupIndex,
                                    in: 0...9
                                ) {
                                    Text("\(draft.captureGroupIndex)")
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .frame(width: 24, alignment: .leading)
                                }
                            }
                        }

                        fieldRow("Keep latest") {
                            Toggle("Replace previous capture from this rule", isOn: $draft.keepOnlyLatest)
                                .font(.system(size: 12))
                                .toggleStyle(.checkbox)
                        }
                    }

                    editorSection("Preview") {
                        fieldRow("Sample") {
                            compactTextField(text: $sampleInput, monospaced: true)
                        }

                        HStack(alignment: .top, spacing: 12) {
                            Text("Result")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(width: 126, alignment: .leading)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(previewResult)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(previewResultColor)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
                                    .padding(10)
                                    .background(TerminalTheme.background)
                                    .overlay(
                                        Rectangle()
                                            .stroke(AppTheme.panelStroke, lineWidth: 1)
                                    )

                                Text("Live capture is active. This preview uses the sample above.")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }
                    }
                }
                .padding(.vertical, 10)
            }

            Divider()
                .overlay(AppTheme.panelStroke)

            sheetFooter
        }
        .frame(width: 620, height: 560)
        .background(AppTheme.current.windowBackground)
        .onChange(of: draft.kind) { _, _ in
            viewModel.applyKindDefaults(to: &draft)
            refreshSampleInput()
        }
        .onAppear {
            refreshSampleInput()
        }
    }

    private var showsExtractPattern: Bool {
        draft.captureMode == .regexGroup || draft.captureMode == .entireMatch
    }

    private var showsCaptureGroup: Bool {
        draft.captureMode == .regexGroup
    }

    private var previewResult: String {
        viewModel.previewCapture(sample: sampleInput, draft: draft) ?? "No capture"
    }

    private var previewResultColor: Color {
        viewModel.previewCapture(sample: sampleInput, draft: draft) == nil
            ? AppTheme.textTertiary
            : AppTheme.textPrimary
    }

    private var sheetHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: draft.kind.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.selectionBlue)

            VStack(alignment: .leading, spacing: 1) {
                Text(draft.isEditing ? "Edit Automation" : "New Automation")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(draft.kind.label)
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
            if draft.isEditing, let ruleID = draft.id,
               let rule = viewModel.rules.first(where: { $0.id == ruleID }) {
                Button("Delete") {
                    viewModel.deleteRule(rule)
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

            Button(draft.isEditing ? "Save Changes" : "Create Automation") {
                viewModel.saveEditorDraft(draft)
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

    private func refreshSampleInput() {
        sampleInput = draft.kind.previewSample(for: draft)
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

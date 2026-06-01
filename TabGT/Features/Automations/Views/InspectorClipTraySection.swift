import SwiftUI

struct InspectorClipTraySection: View {
    @ObservedObject var viewModel: AutomationsViewModel
    var reorderSectionID: InspectorSectionID? = nil
    @State private var manualEntry = ""
    @State private var manualDescription = ""
    @FocusState private var focusedField: ManualEntryField?

    private enum ManualEntryField: Hashable {
        case value
        case description
    }

    private var canAddManualEntry: Bool {
        !manualEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        InspectorAccordionSection(
            title: "Clip Tray",
            storageKey: "tabgt.inspector.expanded.clipTray",
            defaultExpanded: true,
            reorderSectionID: reorderSectionID
        ) {
            manualEntryForm

            if viewModel.capturedClips.isEmpty {
                InspectorEmptyState(message: "No captures yet")
            } else {
                InspectorGroupedList {
                    ForEach(Array(viewModel.capturedClips.enumerated()), id: \.element.id) { index, clip in
                        if index > 0 {
                            InspectorGroupedListDivider()
                        }
                        capturedClipRow(clip)
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.isClipEditorPresented, onDismiss: {
            viewModel.dismissClipEditor()
        }) {
            ClipEditorSheet(
                viewModel: viewModel,
                draft: $viewModel.clipEditorDraft
            )
        }
    }

    private var manualEntryForm: some View {
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                TextField("Add clip manually", text: $manualEntry)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                    .focused($focusedField, equals: .value)
                    .onSubmit(submitManualEntry)

                Button(action: submitManualEntry) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(canAddManualEntry ? AppTheme.selectionBlue : AppTheme.textTertiary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plainClickable)
                .disabled(!canAddManualEntry)
                .help("Add to clip tray")
            }

            TextField("Description (optional)", text: $manualDescription)
                .textFieldStyle(.plain)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(AppTheme.textSecondary)
                .focused($focusedField, equals: .description)
                .onSubmit(submitManualEntry)
        }
        .padding(.horizontal, InspectorMetrics.contentInset)
        .padding(.vertical, 7)
        .background(fieldBackground, in: InspectorMetrics.contentShape)
        .overlay(
            InspectorMetrics.contentShape
                .stroke(fieldBorder, lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.12), value: focusedField)
    }

    private var fieldBackground: Color {
        focusedField != nil
            ? AppTheme.editor.opacity(0.92)
            : InspectorMetrics.contentFill
    }

    private var fieldBorder: Color {
        focusedField != nil
            ? AppTheme.selectionBlue.opacity(0.40)
            : AppTheme.panelStroke.opacity(0.45)
    }

    private func submitManualEntry() {
        guard viewModel.addManualClip(manualEntry, description: manualDescription) else { return }
        manualEntry = ""
        manualDescription = ""
        focusedField = .value
    }

    private func capturedClipRow(_ clip: CapturedClip) -> some View {
        InspectorGroupedListRow {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(clip.value)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .textSelection(.enabled)

                    if let description = clip.description {
                        Text(description)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }

                    HStack(spacing: 4) {
                        Text("from \(clip.sourceLabel)")
                            .lineLimit(1)

                        Text("·")
                            .foregroundStyle(AppTheme.textTertiary)

                        Text(viewModel.relativeCaptureTime(for: clip))
                    }
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(AppTheme.textTertiary)
                }

                Spacer(minLength: 0)

                HStack(spacing: 0) {
                    clipActionButton("pencil", help: "Edit clip") {
                        viewModel.presentEditClip(for: clip)
                    }

                    clipActionButton("doc.on.doc", help: "Copy to clipboard") {
                        viewModel.copyToPasteboard(clip)
                    }

                    clipActionButton("xmark", help: "Remove clip") {
                        viewModel.removeClip(clip)
                    }
                }
            }
        }
        .contextMenu {
            Button("Edit") {
                viewModel.presentEditClip(for: clip)
            }

            Button("Copy") {
                viewModel.copyToPasteboard(clip)
            }

            Button("Delete", role: .destructive) {
                viewModel.removeClip(clip)
            }
        }
    }

    private func clipActionButton(
        _ systemImage: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.textTertiary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plainClickable)
        .help(help)
    }
}

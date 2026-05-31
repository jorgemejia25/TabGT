import SwiftUI

struct InspectorClipTraySection: View {
    @ObservedObject var viewModel: AutomationsViewModel
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
            defaultExpanded: true
        ) {
            manualEntryForm
                .padding(.bottom, 6)

            if viewModel.capturedClips.isEmpty {
                Text("No captures yet — add one above")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 24)
            } else {
                ForEach(viewModel.capturedClips) { clip in
                    capturedClipRow(clip)
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
        VStack(spacing: 6) {
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
                        .frame(width: 22, height: 22)
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
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(fieldBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(fieldBorder, lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.12), value: focusedField)
    }

    private var fieldBackground: Color {
        focusedField != nil
            ? AppTheme.editor.opacity(0.92)
            : AppTheme.editor.opacity(0.55)
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

            HStack(spacing: 2) {
                Button {
                    viewModel.presentEditClip(for: clip)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plainClickable)
                .help("Edit clip")

                Button {
                    viewModel.copyToPasteboard(clip)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plainClickable)
                .help("Copy to clipboard")

                Button {
                    viewModel.removeClip(clip)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plainClickable)
                .help("Remove clip")
            }
        }
        .frame(minHeight: 36)
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
}

import SwiftUI

struct InspectorSnippetsSection: View {
    @ObservedObject var viewModel: SnippetsViewModel
    var sessionID: UUID?

    @State private var filterText = ""

    private var filteredSnippets: [CommandSnippet] {
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return viewModel.snippets }
        return viewModel.matchingSnippets(for: query)
    }

    var body: some View {
        InspectorAccordionSection(
            title: "Snippets",
            storageKey: "tabgt.inspector.expanded.snippets",
            defaultExpanded: true
        ) {
            SearchField(text: $filterText, placeholder: "Filter snippets")
                .padding(.bottom, 6)

            if filteredSnippets.isEmpty {
                Text(emptyStateMessage)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(filteredSnippets) { snippet in
                        snippetRow(snippet)

                        if snippet.id != filteredSnippets.last?.id {
                            Rectangle()
                                .fill(AppTheme.panelStroke.opacity(0.55))
                                .frame(height: 1)
                                .padding(.vertical, 6)
                        }
                    }
                }
            }

            Button {
                viewModel.presentCreateEditor()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                    Text("New Snippet")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(AppTheme.selectionBlue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plainClickable)
            .padding(.top, 8)
        }
        .sheet(isPresented: $viewModel.isEditorPresented, onDismiss: {
            viewModel.dismissEditor()
        }) {
            SnippetEditorSheet(viewModel: viewModel, draft: $viewModel.editorDraft)
        }
    }

    private var emptyStateMessage: String {
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty && viewModel.snippets.isEmpty {
            return "No snippets yet — create one to get started"
        }
        return "No snippets match your filter"
    }

    private func snippetRow(_ snippet: CommandSnippet) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                triggerPill(snippet.trigger)

                Text(snippet.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                snippetActionsMenu(snippet)
            }

            Text(snippet.command)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            if sessionID != nil {
                HStack(spacing: 6) {
                    snippetActionButton("Insert", systemImage: "arrow.down.left.circle") {
                        insert(snippet, submit: false)
                    }

                    snippetActionButton("Run", systemImage: "play.fill") {
                        insert(snippet, submit: true)
                    }

                    Spacer(minLength: 0)

                    Button {
                        viewModel.presentEditEditor(for: snippet)
                    } label: {
                        Text("Edit")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .buttonStyle(.plainClickable)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu {
            snippetContextMenu(snippet)
        }
    }

    private func triggerPill(_ trigger: String) -> some View {
        Text(trigger)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(AppTheme.selectionBlue)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppTheme.selectionBlue.opacity(0.10), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.selectionBlue.opacity(0.22), lineWidth: 1)
            )
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func snippetActionsMenu(_ snippet: CommandSnippet) -> some View {
        Menu {
            snippetContextMenu(snippet)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textTertiary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    @ViewBuilder
    private func snippetContextMenu(_ snippet: CommandSnippet) -> some View {
        if let sessionID {
            Button("Insert") {
                viewModel.insert(snippet, for: sessionID, submit: false)
            }
            Button("Insert and Run") {
                viewModel.insert(snippet, for: sessionID, submit: true)
            }
            Divider()
        }

        Button("Edit") {
            viewModel.presentEditEditor(for: snippet)
        }

        Button("Delete", role: .destructive) {
            viewModel.deleteSnippet(snippet)
        }
    }

    private func snippetActionButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.elevatedPanel.opacity(0.72), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppTheme.panelStroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plainClickable)
    }

    private func insert(_ snippet: CommandSnippet, submit: Bool) {
        guard let sessionID else { return }
        viewModel.insert(snippet, for: sessionID, submit: submit)
    }
}

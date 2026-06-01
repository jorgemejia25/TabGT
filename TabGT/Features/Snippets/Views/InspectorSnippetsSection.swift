import SwiftUI

struct InspectorSnippetsSection: View {
    @ObservedObject var viewModel: SnippetsViewModel
    var session: TerminalSession?
    var profileContext: SnippetProfileContext?
    var reorderSectionID: InspectorSectionID? = nil

    @State private var filterText = ""

    private var sessionID: UUID? { session?.id }

    private var filteredSnippets: [CommandSnippet] {
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return viewModel.snippets }
        return viewModel.matchingSnippets(for: query)
    }

    var body: some View {
        InspectorAccordionSection(
            title: "Snippets",
            storageKey: "tabgt.inspector.expanded.snippets",
            defaultExpanded: true,
            reorderSectionID: reorderSectionID
        ) {
            SearchField(text: $filterText, placeholder: "Filter snippets")

            if filteredSnippets.isEmpty {
                InspectorEmptyState(message: emptyStateMessage)
            } else {
                InspectorGroupedList {
                    ForEach(Array(filteredSnippets.enumerated()), id: \.element.id) { index, snippet in
                        if index > 0 {
                            InspectorGroupedListDivider()
                        }
                        snippetRow(snippet)
                    }
                }
            }

            InspectorLinkButton(title: "New Snippet", systemImage: "plus") {
                viewModel.presentCreateEditor()
            }
        }
        .sheet(isPresented: $viewModel.isEditorPresented, onDismiss: {
            viewModel.dismissEditor()
        }) {
            SnippetEditorSheet(
                viewModel: viewModel,
                draft: $viewModel.editorDraft,
                profileContext: profileContext
            )
        }
    }

    private var emptyStateMessage: String {
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty && viewModel.snippets.isEmpty {
            return "No snippets yet"
        }
        return "No matches"
    }

    private func snippetRow(_ snippet: CommandSnippet) -> some View {
        InspectorGroupedListRow {
            VStack(alignment: .leading, spacing: 5) {
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

                Text(SnippetLaunchResolver.launchSummary(for: snippet, context: profileContext))
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(AppTheme.textTertiary)

                if sessionID != nil {
                    HStack(spacing: 5) {
                        InspectorInlineAction(title: "Paste", systemImage: "doc.on.clipboard") {
                            paste(snippet)
                        }

                        InspectorInlineAction(title: "Run", systemImage: "play.fill") {
                            runInCurrentTab(snippet)
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
        }
        .contentShape(Rectangle())
        .contextMenu {
            snippetContextMenu(snippet)
        }
    }

    private func triggerPill(_ trigger: String) -> some View {
        Text(trigger)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(AppTheme.selectionBlue)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(AppTheme.selectionBlue.opacity(0.10), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.selectionBlue.opacity(0.20), lineWidth: 1)
            )
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func snippetActionsMenu(_ snippet: CommandSnippet) -> some View {
        Menu {
            snippetContextMenu(snippet)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textTertiary)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    @ViewBuilder
    private func snippetContextMenu(_ snippet: CommandSnippet) -> some View {
        if sessionID != nil {
            Button("Paste") {
                paste(snippet)
            }
            Button("Run in New Tab") {
                runInNewTab(snippet)
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

    private func paste(_ snippet: CommandSnippet) {
        guard let sessionID else { return }
        viewModel.insert(snippet, for: sessionID, submit: false)
    }

    private func runInCurrentTab(_ snippet: CommandSnippet) {
        guard let sessionID else { return }
        viewModel.run(snippet, from: sessionID)
    }

    private func runInNewTab(_ snippet: CommandSnippet) {
        guard let sessionID else { return }
        viewModel.runInNewTab(snippet, from: sessionID)
    }
}

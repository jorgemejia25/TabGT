import SwiftUI

struct SnippetsScreen: View {
    @ObservedObject var viewModel: SnippetsViewModel
    var session: TerminalSession?
    var profileContext: SnippetProfileContext?

    @State private var filterText = ""

    private var filteredSnippets: [CommandSnippet] {
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return viewModel.snippets }
        return viewModel.matchingSnippets(for: query)
    }

    var body: some View {
        VStack(spacing: 0) {
            screenHeader

            if viewModel.snippets.isEmpty && filterText.isEmpty {
                emptyState
            } else {
                snippetList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.editor)
        .sheet(isPresented: $viewModel.isEditorPresented, onDismiss: viewModel.dismissEditor) {
            SnippetEditorSheet(
                viewModel: viewModel,
                draft: $viewModel.editorDraft,
                profileContext: profileContext
            )
        }
    }

    private var screenHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Snippets")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(
                    viewModel.snippets.count == 1
                        ? "1 saved command"
                        : "\(viewModel.snippets.count) saved commands"
                )
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textTertiary)
            }

            Spacer()

            SearchField(text: $filterText, placeholder: "Search snippets")
                .frame(width: 220)

            Button {
                viewModel.presentCreateEditor()
            } label: {
                Label("New Snippet", systemImage: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.selectionBlue)
        }
        .padding(.horizontal, 20)
        .frame(height: 54)
        .background(AppTheme.toolbar)
        .shellEdgeBorder(.bottom)
    }

    @ViewBuilder
    private var snippetList: some View {
        if filteredSnippets.isEmpty {
            VStack {
                Spacer()
                Text("No snippets match your search")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textTertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredSnippets) { snippet in
                        snippetCard(snippet)
                        if snippet.id != filteredSnippets.last?.id {
                            Rectangle()
                                .fill(AppTheme.panelStroke.opacity(0.5))
                                .frame(height: 1)
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .scrollIndicators(.never)
        }
    }

    private func snippetCard(_ snippet: CommandSnippet) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    triggerPill(snippet.trigger)

                    Text(snippet.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    if !snippet.tags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(snippet.tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(AppTheme.textTertiary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.elevatedPanel, in: Capsule())
                            }
                        }
                    }
                }

                Text(snippet.command)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                if !snippet.notes.isEmpty {
                    Text(snippet.notes)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textTertiary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(SnippetLaunchResolver.launchSummary(for: snippet, context: profileContext))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
            }

            Spacer(minLength: 20)

            VStack(alignment: .trailing, spacing: 8) {
                if let session {
                    HStack(spacing: 6) {
                        actionButton("Paste", systemImage: "doc.on.clipboard") {
                            viewModel.insert(snippet, for: session.id, submit: false)
                        }
                        actionButton("Run", systemImage: "play.fill") {
                            viewModel.run(snippet, from: session.id)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button("Edit") {
                        viewModel.presentEditEditor(for: snippet)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.selectionBlue)
                    .buttonStyle(.plainClickable)

                    Button("Delete") {
                        viewModel.deleteSnippet(snippet)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.danger)
                    .buttonStyle(.plainClickable)
                }
            }
            .frame(minWidth: 120, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Edit") { viewModel.presentEditEditor(for: snippet) }
            if let session {
                Divider()
                Button("Paste") { viewModel.insert(snippet, for: session.id, submit: false) }
                Button("Run") { viewModel.run(snippet, from: session.id) }
            }
            Divider()
            Button("Delete", role: .destructive) { viewModel.deleteSnippet(snippet) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "text.word.spacing")
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(AppTheme.textTertiary)

            Text("No snippets yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            Text("Create reusable commands to launch quickly across sessions.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Button {
                viewModel.presentCreateEditor()
            } label: {
                Label("New Snippet", systemImage: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.selectionBlue)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func triggerPill(_ trigger: String) -> some View {
        Text(trigger)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(AppTheme.selectionBlue)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppTheme.selectionBlue.opacity(0.10), in: Capsule())
            .overlay(Capsule().stroke(AppTheme.selectionBlue.opacity(0.22), lineWidth: 1))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func actionButton(
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
                .overlay(Capsule().stroke(AppTheme.panelStroke, lineWidth: 1))
        }
        .buttonStyle(.plainClickable)
    }
}

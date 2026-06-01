import SwiftUI

struct InspectorWorkspaceFolderSection: View {
    var session: TerminalSession?
    var host: SSHHost?
    var terminalProfiles: TerminalProfilesViewModel
    @ObservedObject var treeViewModel: WorkspaceFolderTreeViewModel
    @ObservedObject var inputBridge: SessionInputBridge
    var reorderSectionID: InspectorSectionID? = nil

    var body: some View {
        InspectorAccordionSection(
            title: "Workspace",
            storageKey: "tabgt.inspector.expanded.workspace",
            defaultExpanded: true,
            reorderSectionID: reorderSectionID
        ) {
            InspectorRowGroup {
                InspectorRow(label: "Shell", value: shellPathLabel, monospacedValue: true)
            }

            InspectorGroupedList {
                currentDirectoryHeader
                folderBody
            }
        }
        .onChange(of: session?.id) { _, _ in
            treeViewModel.bind(session: session, host: host)
        }
        .onChange(of: session?.currentDirectory) { _, _ in
            treeViewModel.bind(session: session, host: host)
        }
        .onChange(of: session?.effectiveDirectory) { _, _ in
            treeViewModel.bind(session: session, host: host)
        }
        .onChange(of: session?.state) { _, _ in
            treeViewModel.bind(session: session, host: host)
        }
        .onAppear {
            treeViewModel.bind(session: session, host: host)
        }
    }

    private var currentDirectoryHeader: some View {
        InspectorGroupedListRow {
            HStack(spacing: 8) {
                Button {
                    goUpOneLevel()
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(treeViewModel.canGoUp ? AppTheme.textSecondary : AppTheme.textTertiary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plainClickable)
                .disabled(!treeViewModel.canGoUp)
                .help("Go to parent folder")

                VStack(alignment: .leading, spacing: 1) {
                    Text(treeViewModel.currentFolderName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    Text(treeViewModel.displayPath)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(AppTheme.textTertiary)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var folderBody: some View {
        switch treeViewModel.phase {
        case .idle:
            EmptyView()
        case .loading:
            InspectorGroupedListDivider()
            inlineStatus("Loading folder…")
        case .ready:
            if treeViewModel.visibleRows.isEmpty {
                InspectorGroupedListDivider()
                inlineStatus("Empty folder")
            } else {
                InspectorGroupedListDivider()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(treeViewModel.visibleRows) { row in
                            FolderTreeRow(
                                row: row,
                                onOpen: row.isDirectory ? {
                                    changeDirectory(to: row.path)
                                } : nil,
                                onChangeDirectory: row.isDirectory ? {
                                    changeDirectory(to: row.path)
                                } : nil
                            )
                        }
                    }
                    .padding(.horizontal, InspectorMetrics.contentInset)
                    .padding(.bottom, 4)
                }
                .frame(maxHeight: 220)
            }
        case .unavailable(let message):
            InspectorGroupedListDivider()
            inlineStatus(message)
        case .failed(let message):
            InspectorGroupedListDivider()
            inlineStatus(message)
        }
    }

    private func inlineStatus(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(AppTheme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, InspectorMetrics.contentInset)
            .padding(.vertical, 7)
    }

    private var shellPathLabel: String {
        guard let session else { return "-" }
        switch session.kind {
        case .localShell(let profileID, _):
            return terminalProfiles.profile(for: profileID)?.shellPath ?? "-"
        case .ssh:
            return host?.remoteShell ?? "Default remote shell"
        case .diagnostic:
            return "-"
        }
    }

    private func goUpOneLevel() {
        guard let parent = treeViewModel.parentPath else { return }
        changeDirectory(to: parent)
    }

    private func changeDirectory(to path: String) {
        guard let session,
              let command = WorkspaceDirectoryCommand.changeDirectory(for: path, session: session, host: host) else {
            return
        }

        inputBridge.send(text: command, to: session.id, submit: true)
    }
}

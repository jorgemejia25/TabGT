import SwiftUI

struct InspectorPanel: View {
    var host: SSHHost?
    var session: TerminalSession?
    @ObservedObject var connections: ConnectionsViewModel
    @ObservedObject var terminalProfiles: TerminalProfilesViewModel
    @ObservedObject var automations: AutomationsViewModel
    @ObservedObject var snippets: SnippetsViewModel
    @ObservedObject var inputBridge: SessionInputBridge
    @ObservedObject var sessions: SessionsViewModel
    @ObservedObject private var layoutStore = InspectorLayoutStore.shared
    @StateObject private var workspaceTree = WorkspaceFolderTreeViewModel()
    var onEditHost: ((SSHHost) -> Void)?
    var onDeleteHost: ((SSHHost) -> Void)?
    var onEditLocalProfile: ((LocalTerminalProfile) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            inspectorHeader

            ScrollView {
                InspectorSectionReorderList(
                    sections: visibleSections,
                    layoutStore: layoutStore
                ) { section in
                    sectionContent(for: section)
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.never)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.navigator)
        .shellEdgeBorder(.leading)
    }

    private var inspectorHeader: some View {
        HStack(spacing: 8) {
            Text("Inspector")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer(minLength: 0)

            if !hiddenSections.isEmpty {
                hiddenSectionsMenu
            }
        }
        .padding(.horizontal, InspectorMetrics.panelInset)
        .frame(height: ShellLayout.panelHeaderHeight)
        .frame(maxWidth: .infinity)
        .background(AppTheme.navigator)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.splitSash)
                .frame(height: 1)
        }
    }

    private var visibleSections: [InspectorSectionID] {
        layoutStore.visibleSections(hasSSHHost: sessionHost != nil)
    }

    private var hiddenSections: [InspectorSectionID] {
        layoutStore.allHiddenSections()
    }

    private var hiddenSectionsMenu: some View {
        Menu {
            ForEach(hiddenSections) { section in
                Button {
                    layoutStore.setVisible(section, visible: true)
                } label: {
                    Label("Show \(section.title)", systemImage: section.systemImage)
                }
            }

            Divider()

            Button("Show All") {
                layoutStore.showAllHiddenSections()
            }
        } label: {
            Image(systemName: "eye.slash")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textTertiary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .help("Hidden sections")
    }

    @ViewBuilder
    private func sectionContent(for section: InspectorSectionID) -> some View {
        switch section {
        case .connection:
            InspectorAccordionSection(
                title: InspectorSectionID.connection.title,
                storageKey: InspectorSectionID.connection.expandedStorageKey,
                defaultExpanded: InspectorSectionID.connection.defaultExpanded,
                reorderSectionID: .connection
            ) {
                InspectorRowGroup {
                    InspectorRow(label: "Name", value: host?.name ?? "-")
                    InspectorRow(label: "Host", value: host?.address ?? "-")
                    InspectorRow(label: "User", value: host?.username ?? "-")
                    InspectorRow(label: "Port", value: host.map { "\($0.port)" } ?? "-")
                    InspectorRow(label: "Auth", value: host?.credentialRef?.label ?? "Unassigned")
                }

                if let host, let onEditHost {
                    InspectorLinkButton(title: "Edit SSH Profile", systemImage: "pencil", action: { onEditHost(host) })
                }
                if let host, let onDeleteHost {
                    InspectorLinkButton(title: "Delete SSH Profile", role: .destructive, action: { onDeleteHost(host) })
                }
            }

        case .session:
            InspectorAccordionSection(
                title: InspectorSectionID.session.title,
                storageKey: InspectorSectionID.session.expandedStorageKey,
                defaultExpanded: InspectorSectionID.session.defaultExpanded,
                reorderSectionID: .session
            ) {
                InspectorRowGroup {
                    InspectorRow(label: "Type", value: sessionKind)
                    InspectorRow(label: "State", value: session?.state.label ?? "Idle")
                    InspectorRow(label: "PID", value: "mock")
                    InspectorRow(label: "Size", value: session.map { "\($0.columns)x\($0.rows)" } ?? "-")
                    InspectorRow(label: "Encoding", value: session?.encoding ?? "UTF-8")
                    InspectorRow(label: "Startup folder", value: activeEffectiveDirectory, valueLineLimit: 2)
                }

                if let profile = activeLocalProfile, let onEditLocalProfile {
                    InspectorLinkButton(title: "Edit Local Profile", systemImage: "pencil", action: { onEditLocalProfile(profile) })
                }
            }

        case .claudeCode:
            if let sshHost = sessionHost {
                InspectorClaudeCodeSection(
                    host: sshHost,
                    sessionID: session?.id,
                    claudeSession: session?.claudeSession,
                    sessions: sessions,
                    reorderSectionID: .claudeCode
                )
            }

        case .git:
            InspectorGitSection(
                gitState: session?.gitRepoState,
                reorderSectionID: .git
            )

        case .workspace:
            InspectorWorkspaceFolderSection(
                session: session,
                host: sessionHost,
                terminalProfiles: terminalProfiles,
                treeViewModel: workspaceTree,
                inputBridge: inputBridge,
                reorderSectionID: .workspace
            )

        case .automations:
            InspectorAutomationsSection(
                viewModel: automations,
                snippets: snippets,
                reorderSectionID: .automations
            )

        case .snippets:
            InspectorSnippetsSection(
                viewModel: snippets,
                session: session,
                profileContext: snippetProfileContext,
                reorderSectionID: .snippets
            )

        case .clipTray:
            InspectorClipTraySection(
                viewModel: automations,
                reorderSectionID: .clipTray
            )

        case .security:
            InspectorAccordionSection(
                title: InspectorSectionID.security.title,
                storageKey: InspectorSectionID.security.expandedStorageKey,
                defaultExpanded: InspectorSectionID.security.defaultExpanded,
                reorderSectionID: .security
            ) {
                InspectorRowGroup {
                    InspectorRow(label: "Key path", value: "~/.ssh/id_ed25519", monospacedValue: true)
                    InspectorRow(label: "Agent status", value: "Available")
                    InspectorRow(label: "Known host", value: "Trusted")
                }
            }
        }
    }

    private var sessionKind: String {
        guard let session else { return "-" }
        switch session.kind {
        case .ssh:
            return "SSH"
        case .localShell:
            return "Local"
        case .diagnostic:
            return "Diagnostic"
        }
    }

    private var activeEffectiveDirectory: String {
        guard let session else { return "-" }
        return session.effectiveDirectory ?? "-"
    }

    private var sessionHost: SSHHost? {
        guard let session else { return nil }
        return connections.host(for: session)
    }

    private var activeLocalProfile: LocalTerminalProfile? {
        guard let session,
              case .localShell(let profileID, _) = session.kind else {
            return nil
        }
        return terminalProfiles.profile(for: profileID)
    }

    private var snippetProfileContext: SnippetProfileContext? {
        guard let session else { return nil }
        return snippets.profileContext(for: session)
    }
}

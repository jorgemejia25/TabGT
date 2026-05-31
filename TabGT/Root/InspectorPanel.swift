import SwiftUI

struct InspectorPanel: View {
    var host: SSHHost?
    var session: TerminalSession?
    @ObservedObject var terminalProfiles: TerminalProfilesViewModel
    @ObservedObject var automations: AutomationsViewModel
    @ObservedObject var snippets: SnippetsViewModel
    var onEditHost: ((SSHHost) -> Void)?
    var onDeleteHost: ((SSHHost) -> Void)?
    var onEditLocalProfile: ((LocalTerminalProfile) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Inspector")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: ShellLayout.panelHeaderHeight)
            .frame(maxWidth: .infinity)
            .background(AppTheme.navigator)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AppTheme.splitSash)
                    .frame(height: 1)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    InspectorAccordionSection(
                        title: "Connection",
                        storageKey: "tabgt.inspector.expanded.connection",
                        defaultExpanded: true
                    ) {
                        inspectorRow("Name", host?.name ?? "-")
                        inspectorRow("Host", host?.address ?? "-")
                        inspectorRow("User", host?.username ?? "-")
                        inspectorRow("Port", host.map { "\($0.port)" } ?? "-")
                        inspectorRow("Auth", host?.credentialRef?.label ?? "Unassigned")
                        if let host, let onEditHost {
                            editProfileButton("Edit SSH Profile") { onEditHost(host) }
                        }
                        if let host, let onDeleteHost {
                            deleteProfileButton("Delete SSH Profile") { onDeleteHost(host) }
                        }
                    }

                    InspectorAccordionSection(
                        title: "Session",
                        storageKey: "tabgt.inspector.expanded.session",
                        defaultExpanded: false
                    ) {
                        inspectorRow("Type", sessionKind)
                        inspectorRow("State", session?.state.label ?? "Idle")
                        inspectorRow("PID", "mock")
                        inspectorRow("Size", session.map { "\($0.columns)x\($0.rows)" } ?? "-")
                        inspectorRow("Encoding", session?.encoding ?? "UTF-8")
                        inspectorRow("Startup folder", activeWorkingDirectory)
                        if let profile = activeLocalProfile, let onEditLocalProfile {
                            editProfileButton("Edit Local Profile") { onEditLocalProfile(profile) }
                        }
                    }

                    InspectorAccordionSection(
                        title: "Workspace",
                        storageKey: "tabgt.inspector.expanded.workspace",
                        defaultExpanded: false
                    ) {
                        inspectorRow("Working directory", activeWorkingDirectory)
                        inspectorRow("Shell", activeShellPath)
                        inspectorRow("Startup command", "-")
                        inspectorRow("tmux session", "-")
                    }

                    InspectorAutomationsSection(viewModel: automations, snippets: snippets)
                    InspectorSnippetsSection(viewModel: snippets, sessionID: session?.id)
                    InspectorClipTraySection(viewModel: automations)

                    InspectorAccordionSection(
                        title: "Security",
                        storageKey: "tabgt.inspector.expanded.security",
                        defaultExpanded: false
                    ) {
                        inspectorRow("Key path", "~/.ssh/id_ed25519")
                        inspectorRow("Agent status", "Available")
                        inspectorRow("Known host", "Trusted")
                    }
                }
            }
            .scrollIndicators(.never)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.navigator)
        .shellEdgeBorder(.leading)
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

    private var activeWorkingDirectory: String {
        guard let session else { return "-" }
        return session.kind.workingDirectory ?? "-"
    }

    private var activeShellPath: String {
        guard let session,
              case .localShell(let profileID, _) = session.kind,
              let profile = terminalProfiles.profile(for: profileID) else {
            return "-"
        }
        return profile.shellPath
    }

    private var activeLocalProfile: LocalTerminalProfile? {
        guard let session,
              case .localShell(let profileID, _) = session.kind else {
            return nil
        }
        return terminalProfiles.profile(for: profileID)
    }

    private func editProfileButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.selectionBlue)
        }
        .buttonStyle(.plainClickable)
        .frame(height: 28)
    }

    private func deleteProfileButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
        }
        .buttonStyle(.plainClickable)
        .frame(height: 28)
    }

    private func inspectorRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(key)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 96, alignment: .leading)

            Text(value.isEmpty ? "-" : value)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .frame(height: 24)
    }
}

import SwiftUI

struct InspectorClaudeCodeSection: View {
    var host: SSHHost
    var sessionID: UUID?
    var claudeSession: ClaudeSessionState?
    @ObservedObject var sessions: SessionsViewModel
    var reorderSectionID: InspectorSectionID? = nil

    @State private var installState: InstallState = .unknown

    private enum InstallState {
        case unknown, checking, installed, notInstalled, installing, error(String)
    }

    var body: some View {
        InspectorAccordionSection(
            title: "Claude Code",
            storageKey: "tabgt.inspector.expanded.claudeCode",
            defaultExpanded: true,
            reorderSectionID: reorderSectionID
        ) {
            switch installState {
            case .unknown, .checking:
                InspectorEmptyState(message: "Checking hook installation…")

            case .notInstalled:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Install TabGT hooks on the remote host to receive Claude Code session info.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    InspectorLinkButton(title: "Install Claude Code Hooks", systemImage: "arrow.down.circle") {
                        Task { await install() }
                    }
                }

            case .installing:
                InspectorEmptyState(message: "Installing hooks…")

            case .installed:
                sessionContent

            case .error(let msg):
                VStack(alignment: .leading, spacing: 8) {
                    Text(msg)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.danger)
                        .fixedSize(horizontal: false, vertical: true)

                    InspectorLinkButton(title: "Retry Install", systemImage: "arrow.clockwise") {
                        Task { await install() }
                    }
                }
            }
        }
        .task(id: host.id) { await checkInstallStatus() }
    }

    @ViewBuilder
    private var sessionContent: some View {
        let claude = claudeSession

        InspectorRowGroup {
            InspectorRow(
                label: "Status",
                value: claude.map { $0.isActive ? "Active" : "Idle" } ?? "Idle"
            )

            if let tool = claude?.currentTool {
                InspectorRow(label: "Tool", value: tool)
            }

            if let cwd = claude?.workingDirectory {
                InspectorRow(label: "Working dir", value: cwd, valueLineLimit: 2)
            }

            if let files = claude?.modifiedFiles, !files.isEmpty {
                InspectorRow(label: "Modified", value: "\(files.count) file\(files.count == 1 ? "" : "s")")

                VStack(alignment: .leading, spacing: 3) {
                    ForEach(files.suffix(5), id: \.self) { file in
                        Text(URL(fileURLWithPath: file).lastPathComponent)
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                            .textSelection(.enabled)
                    }
                    if files.count > 5 {
                        Text("+ \(files.count - 5) more")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
                .padding(.leading, InspectorMetrics.labelWidth + 12)
            }

            if let cost = claude?.estimatedCost {
                InspectorRow(label: "Est. cost", value: String(format: "$%.4f", cost))
            }

            if let start = claude?.sessionStartedAt {
                InspectorRow(label: "Duration", value: durationString(since: start))
            }
        }

        InspectorLinkButton(title: "Repair Hooks", systemImage: "wrench.and.screwdriver") {
            Task { await repair() }
        }

        InspectorLinkButton(title: "Remove Hooks", systemImage: "trash", role: .destructive) {
            Task { await uninstall() }
        }
    }

    private func repair() async {
        installState = .installing
        do {
            try await ClaudeHookInstaller.shared.repairHooks(on: host)
            installState = .installed
        } catch {
            installState = .error(error.localizedDescription)
        }
    }

    private func checkInstallStatus() async {
        installState = .checking
        let installed = await ClaudeHookInstaller.shared.isInstalled(on: host)
        installState = installed ? .installed : .notInstalled
    }

    private func install() async {
        installState = .installing
        do {
            try await ClaudeHookInstaller.shared.install(on: host)
            installState = .installed
        } catch {
            installState = .error(error.localizedDescription)
        }
    }

    private func uninstall() async {
        do {
            try await ClaudeHookInstaller.shared.uninstall(from: host)
            if let sid = sessionID {
                sessions.clearClaudeSession(sessionID: sid)
            }
            installState = .notInstalled
        } catch {
            installState = .error(error.localizedDescription)
        }
    }

    private func durationString(since date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m \(seconds % 60)s" }
        return "\(seconds / 3600)h \(seconds % 3600 / 60)m"
    }
}

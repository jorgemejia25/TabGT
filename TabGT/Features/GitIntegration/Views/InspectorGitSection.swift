import SwiftUI

struct InspectorGitSection: View {
    var gitState: GitRepoState?
    var reorderSectionID: InspectorSectionID? = nil

    var body: some View {
        InspectorAccordionSection(
            title: "Git",
            storageKey: "tabgt.inspector.expanded.git",
            defaultExpanded: true,
            reorderSectionID: reorderSectionID
        ) {
            if let git = gitState {
                gitContent(git)
            } else {
                InspectorEmptyState(message: "No git repository detected in the current directory.")
            }
        }
    }

    @ViewBuilder
    private func gitContent(_ git: GitRepoState) -> some View {
        InspectorRowGroup {
            InspectorRow(label: "Branch", value: branchLabel(git))
            InspectorRow(label: "Status", value: git.statusSummary)

            if git.aheadCount > 0 || git.behindCount > 0 {
                InspectorRow(label: "Upstream", value: upstreamLabel(git))
            }

            if let hash = git.lastCommitHash, let msg = git.lastCommitMessage {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Commit")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(width: InspectorMetrics.labelWidth, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(hash)
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(msg)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: InspectorMetrics.rowHeight)
            }
        }
    }

    private func branchLabel(_ git: GitRepoState) -> String {
        if git.isDetached { return "HEAD (detached)" }
        return git.branch ?? "—"
    }

    private func upstreamLabel(_ git: GitRepoState) -> String {
        var parts: [String] = []
        if git.aheadCount > 0  { parts.append("↑\(git.aheadCount)") }
        if git.behindCount > 0 { parts.append("↓\(git.behindCount)") }
        return parts.joined(separator: " ")
    }
}

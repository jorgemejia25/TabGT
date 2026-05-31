import SwiftUI

struct SSHConfigImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var aliases = SSHConfigImportRow.previewRows

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .overlay(AppTheme.panelStroke)

            VStack(spacing: 0) {
                tableHeader

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach($aliases) { $alias in
                            SSHConfigImportTableRow(row: $alias)
                        }
                    }
                }
            }
            .background(AppTheme.editor)

            Divider()
                .overlay(AppTheme.panelStroke)

            footer
        }
        .frame(width: 820, height: 520)
        .background(AppTheme.current.windowBackground)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.selectionBlue)

            VStack(alignment: .leading, spacing: 1) {
                Text("Import SSH Config")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("~/.ssh/config")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(AppTheme.textTertiary)
            }

            Spacer()

            Button("Reload") {}
                .font(.system(size: 12, weight: .medium))
                .buttonStyle(.plainClickable)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(AppTheme.toolbar)
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            tableHeading("", width: 34)
            tableHeading("Alias", width: 124)
            tableHeading("HostName", width: 156)
            tableHeading("User", width: 108)
            tableHeading("Port", width: 54)
            tableHeading("IdentityFile", width: 188)
            tableHeading("ProxyJump", width: 132)
            Spacer(minLength: 0)
        }
        .frame(height: 28)
        .background(AppTheme.toolbar.opacity(0.88))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.panelStroke)
                .frame(height: 1)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("\(selectedCount) selected")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .font(.system(size: 12, weight: .medium))
            .buttonStyle(.plainClickable)

            Button("Import Selected") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.selectionBlue)
            .font(.system(size: 12, weight: .semibold))
            .disabled(selectedCount == 0)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(AppTheme.toolbar)
    }

    private var selectedCount: Int {
        aliases.filter(\.isSelected).count
    }

    private func tableHeading(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(AppTheme.textTertiary)
            .textCase(.uppercase)
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, text.isEmpty ? 0 : 8)
    }
}

private struct SSHConfigImportTableRow: View {
    @Binding var row: SSHConfigImportRow

    var body: some View {
        HStack(spacing: 0) {
            Toggle("", isOn: $row.isSelected)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .frame(width: 34)

            cell(row.alias, width: 124, primary: true)
            cell(row.hostName, width: 156)
            cell(row.user, width: 108)
            cell(String(row.port), width: 54)
            cell(row.identityFile, width: 188, monospaced: true)
            cell(row.proxyJump ?? "-", width: 132, monospaced: true)

            Spacer(minLength: 0)
        }
        .frame(height: 30)
        .background(row.isSelected ? AppTheme.selectionBlueMuted.opacity(0.34) : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.panelStroke.opacity(0.62))
                .frame(height: 1)
        }
    }

    private func cell(
        _ text: String,
        width: CGFloat,
        primary: Bool = false,
        monospaced: Bool = false
    ) -> some View {
        Text(text)
            .font(.system(size: 11, weight: primary ? .semibold : .regular, design: monospaced ? .monospaced : .default))
            .foregroundStyle(primary ? AppTheme.textPrimary : AppTheme.textSecondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, 8)
    }
}

private struct SSHConfigImportRow: Identifiable {
    var id = UUID()
    var alias: String
    var hostName: String
    var user: String
    var port: Int
    var identityFile: String
    var proxyJump: String?
    var isSelected: Bool

    static let previewRows = [
        SSHConfigImportRow(
            alias: "api-east-01",
            hostName: "10.18.4.21",
            user: "deploy",
            port: 22,
            identityFile: "~/.ssh/prod_ed25519",
            proxyJump: "bastion-prod",
            isSelected: true
        ),
        SSHConfigImportRow(
            alias: "staging-app",
            hostName: "staging.internal",
            user: "developer",
            port: 22,
            identityFile: "~/.ssh/id_ed25519",
            proxyJump: nil,
            isSelected: true
        ),
        SSHConfigImportRow(
            alias: "logs-worker",
            hostName: "10.18.8.32",
            user: "ops",
            port: 2202,
            identityFile: "~/.ssh/ops_ed25519",
            proxyJump: "bastion-prod",
            isSelected: false
        )
    ]
}

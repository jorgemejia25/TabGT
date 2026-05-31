import SwiftUI

struct RootSidebar: View {
    @ObservedObject var viewModel: ConnectionsViewModel

    var onOpenHost: (SSHHost) -> Void
    var onOpenLocal: () -> Void

    var body: some View {
        GlassSidebar {
            VStack(alignment: .leading, spacing: 10) {
                header
                SearchField(text: $viewModel.searchText)
                localTerminalButton
                hostGroups
                Spacer(minLength: 0)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("TabGT")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Secure terminals")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    private var localTerminalButton: some View {
        Button(action: onOpenLocal) {
            HStack(spacing: 8) {
                Image(systemName: "macwindow.and.cursorarrow")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.selectionBlue)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Local zsh")
                        .font(.system(size: 12, weight: .semibold))
                    Text("macOS PTY adapter planned")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()
            }
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(AppTheme.editor.opacity(0.50), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.panelStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plainClickable)
    }

    private var hostGroups: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(viewModel.groups) { group in
                    let hosts = viewModel.hosts(in: group)
                    if !hosts.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.name.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.top, 4)

                            ForEach(hosts) { host in
                                HostRowView(
                                    host: host,
                                    isSelected: host.id == viewModel.selectedHostID,
                                    onOpen: {
                                        onOpenHost(host)
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }
}

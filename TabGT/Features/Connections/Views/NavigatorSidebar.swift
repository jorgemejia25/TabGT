import SwiftUI

struct NavigatorSidebar: View {
    @ObservedObject var connections: ConnectionsViewModel
    @ObservedObject var terminalProfiles: TerminalProfilesViewModel
    @Binding var destination: RootDestination

    var onOpenHost: (SSHHost, StartupFolder?) -> Void
    var onOpenLocalProfile: (LocalTerminalProfile, StartupFolder?) -> Void
    var onEditHost: (SSHHost) -> Void
    var onDeleteHost: (SSHHost) -> Void
    var onEditLocalProfile: (LocalTerminalProfile) -> Void
    var onNewProfile: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            SearchField(text: $connections.searchText)
                .padding(.horizontal, 12)
                .padding(.top, 14)
                .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if connections.hosts.isEmpty {
                        SSHEmptyProfilesPlaceholder(onAddProfile: onNewProfile)
                    }

                    ForEach(connections.groups) { group in
                        let groupHosts = connections.hosts(in: group)
                        if !groupHosts.isEmpty {
                            SidebarSection(title: group.name) {
                                ForEach(groupHosts) { host in
                                    SSHProfileRow(
                                        host: host,
                                        isSelected: host.id == connections.selectedHostID,
                                        onOpen: { folder in open(host, folder: folder) },
                                        onEdit: { onEditHost(host) },
                                        onDelete: { onDeleteHost(host) }
                                    )
                                }
                            }
                        }
                    }

                    let ungrouped = connections.filteredHosts.filter { $0.groupID == nil }
                    if !ungrouped.isEmpty {
                        SidebarSection(title: "Other") {
                            ForEach(ungrouped) { host in
                                SSHProfileRow(
                                    host: host,
                                    isSelected: host.id == connections.selectedHostID,
                                    onOpen: { folder in open(host, folder: folder) },
                                    onEdit: { onEditHost(host) },
                                    onDelete: { onDeleteHost(host) }
                                )
                            }
                        }
                    }

                    SidebarSection(title: "Local") {
                        ForEach(terminalProfiles.profiles) { profile in
                            LocalProfileRow(
                                profile: profile,
                                onOpen: { folder in
                                    openLocal(profile, folder: folder)
                                },
                                onEdit: { onEditLocalProfile(profile) }
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.never)
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            navLinksSection

            HStack(spacing: 12) {
                Button(action: onNewProfile) {
                    Label("New Profile", systemImage: "plus")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .buttonStyle(.plainClickable)
                .help("Create a new SSH or local profile")

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .overlay(alignment: .top) {
                Rectangle().fill(AppTheme.splitSash).frame(height: 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.navigator)
        .shellEdgeBorder(.trailing)
    }

    private var sidebarHeader: some View {
        Color.clear
            .frame(height: ShellLayout.toolbarHeight)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AppTheme.shellBorder)
                    .frame(height: 1)
            }
    }

    private var navLinksSection: some View {
        VStack(spacing: 1) {
            navLink("Snippets", systemImage: "text.word.spacing", dest: .snippets)
            navLink("Automations", systemImage: "bolt.fill", dest: .automations)
            navLink("Settings", systemImage: "gearshape", dest: .settings)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .overlay(alignment: .top) {
            Rectangle().fill(AppTheme.splitSash).frame(height: 1)
        }
    }

    private func navLink(_ title: String, systemImage: String, dest: RootDestination) -> some View {
        Button {
            destination = dest
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16, alignment: .center)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .foregroundStyle(destination == dest ? AppTheme.onSelectionText : AppTheme.textSecondary)
            .background(
                destination == dest ? AppTheme.selectionBlue : Color.clear,
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
        }
        .buttonStyle(.plainClickable)
    }

    private func open(_ host: SSHHost, folder: StartupFolder?) {
        connections.select(host)
        destination = .terminal
        onOpenHost(host, folder)
    }

    private func openLocal(_ profile: LocalTerminalProfile, folder: StartupFolder?) {
        destination = .terminal
        onOpenLocalProfile(profile, folder)
    }
}

// MARK: - SSH Empty State

private struct SSHEmptyProfilesPlaceholder: View {
    var onAddProfile: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onAddProfile) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No SSH profiles yet")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)

                    if isHovered {
                        Label("Add Profile", systemImage: "plus")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.selectionBlue)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? AppTheme.rowHoverFill : .clear)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .buttonStyle(.plainClickable)
        .pointerCursor()
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - SSH Profile Row

struct SSHProfileRow: View {
    var host: SSHHost
    var isSelected: Bool
    var onOpen: (StartupFolder?) -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var isHovered = false

    private var defaultFolder: StartupFolder? {
        ProfileResolver.resolvedDefaultFolder(
            folders: host.startupFolders,
            defaultID: host.defaultStartupFolderID
        )
    }

    var body: some View {
        Button {
            onOpen(defaultFolder)
        } label: {
            profileLabel(
                title: host.name,
                subtitle: host.displayAddress
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .buttonStyle(.plainClickable)
        .onHover { isHovered = $0 }
        .contextMenu {
            profileContextMenu(defaultFolder: defaultFolder)
        }
    }

    @ViewBuilder
    private func profileLabel(title: String, subtitle: String) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppTheme.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(rowBackground)
        }
    }

    @ViewBuilder
    private func profileContextMenu(defaultFolder: StartupFolder?) -> some View {
        Button("Open") { onOpen(defaultFolder) }

        if !host.startupFolders.isEmpty {
            Menu("Open In Predefined Folder") {
                ForEach(host.startupFolders) { folder in
                    Button(folder.name) { onOpen(folder) }
                }
            }
        }

        Divider()

        Button("Edit Profile…") { onEdit() }

        Button("Delete Profile…", role: .destructive) { onDelete() }
    }

    private var rowBackground: Color {
        if isSelected { return AppTheme.rowSelectedFill }
        if isHovered { return AppTheme.rowHoverFill }
        return .clear
    }
}

// MARK: - Local Profile Row

struct LocalProfileRow: View {
    var profile: LocalTerminalProfile
    var onOpen: (StartupFolder?) -> Void
    var onEdit: () -> Void

    @State private var isHovered = false

    private var defaultFolder: StartupFolder? {
        ProfileResolver.resolvedDefaultFolder(
            folders: profile.startupFolders,
            defaultID: profile.defaultStartupFolderID
        )
    }

    var body: some View {
        Button {
            onOpen(defaultFolder)
        } label: {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    Text(profile.shellPath)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? AppTheme.rowHoverFill : .clear)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .buttonStyle(.plainClickable)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Open") { onOpen(defaultFolder) }

            if !profile.startupFolders.isEmpty {
                Menu("Open In Predefined Folder") {
                    ForEach(profile.startupFolders) { folder in
                        Button(folder.name) { onOpen(folder) }
                    }
                }
            }

            Divider()

            Button("Edit Profile…") { onEdit() }
        }
    }
}

// MARK: - Section

struct SidebarSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 1) {
                content()
            }
            .padding(.bottom, 4)
        } label: {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.textTertiary)
                .tracking(0.4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .pointerCursor()
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Generic Row

struct SidebarRow: View {
    var title: String
    var subtitle: String?
    var action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? AppTheme.rowHoverFill : .clear)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .buttonStyle(.plainClickable)
        .onHover { isHovered = $0 }
    }
}

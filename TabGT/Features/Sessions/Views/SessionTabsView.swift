import SwiftUI

struct SessionTabsView: View {
    @ObservedObject var viewModel: SessionsViewModel
    @ObservedObject var terminalProfiles: TerminalProfilesViewModel
    var group: TerminalGroup

    var body: some View {
        TerminalGroupHeader(
            viewModel: viewModel,
            terminalProfiles: terminalProfiles,
            group: group
        )
    }
}

// MARK: - Group Header

/// Tab bar + action toolbar for a terminal group.
///
/// Layout mirrors VS Code's editor tabs:
///   [scrollable tabs …] [+] [split] […] [×]
struct TerminalGroupHeader: View {
    @ObservedObject var viewModel: SessionsViewModel
    @ObservedObject var terminalProfiles: TerminalProfilesViewModel
    var group: TerminalGroup

    var body: some View {
        HStack(spacing: 0) {
            TerminalGroupTabBar(viewModel: viewModel, group: group)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(-1)

            tabBarDivider

            groupActions
        }
        .frame(height: ShellLayout.panelHeaderHeight)
        .background(AppTheme.navigator)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.splitSash)
                .frame(height: 1)
        }
    }

    private var tabBarDivider: some View {
        Rectangle()
            .fill(AppTheme.panelStroke.opacity(0.45))
            .frame(width: 1, height: 18)
    }

    // MARK: Action Bar

    private var groupActions: some View {
        HStack(spacing: 0) {
            GroupActionButton(
                systemImage: "plus",
                help: "New Terminal in Group"
            ) {
                if let profile = terminalProfiles.defaultProfile {
                    viewModel.openLocalSession(profile: profile, in: group.id)
                } else {
                    viewModel.openLocalSession(in: group.id)
                }
            }

            GroupActionButton(
                systemImage: "square.split.2x1",
                help: "Split Right"
            ) {
                viewModel.splitGroup(group.id, placement: .right)
            }

            GroupActionButton(
                systemImage: "square.split.1x2",
                help: "Split Down"
            ) {
                viewModel.splitGroup(group.id, placement: .down)
            }

            GroupMoreMenu(viewModel: viewModel, group: group)

            GroupActionButton(
                systemImage: "xmark",
                help: "Close Group"
            ) {
                viewModel.closeGroup(group.id)
            }
            .padding(.leading, 2)
        }
        .padding(.trailing, 6)
        .frame(height: ShellLayout.panelHeaderHeight)
    }
}

// MARK: - Tab Bar

struct TerminalGroupTabBar: View {
    @ObservedObject var viewModel: SessionsViewModel
    var group: TerminalGroup

    var body: some View {
        GeometryReader { geometry in
            let metrics = TerminalTabLayoutMetrics(
                availableWidth: geometry.size.width,
                tabCount: group.sessionIDs.count
            )

            Group {
                if metrics.needsScroll {
                    scrollableTabs(tabWidth: metrics.tabWidth)
                } else {
                    fittedTabs(tabWidth: metrics.tabWidth)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
        }
        .frame(height: ShellLayout.panelHeaderHeight)
        .dropDestination(for: TerminalTabDragPayload.self) { items, _ in
            guard let payload = items.first else { return false }
            guard TabDragDrop.shouldAccept(payload, in: group.id) else { return false }
            viewModel.handleTabDrop(payload, to: group.id)
            return true
        }
    }

    @ViewBuilder
    private func fittedTabs(tabWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            tabItems(tabWidth: tabWidth)
        }
    }

    @ViewBuilder
    private func scrollableTabs(tabWidth: CGFloat) -> some View {
        let contentWidth = tabWidth * CGFloat(group.sessionIDs.count)
        let contentSize = CGSize(
            width: contentWidth,
            height: ShellLayout.panelHeaderHeight
        )

        OverlayHorizontalScrollView(contentSize: contentSize) {
            HStack(spacing: 0) {
                tabItems(tabWidth: tabWidth)
            }
            .frame(width: contentWidth, height: ShellLayout.panelHeaderHeight, alignment: .leading)
        }
    }

    @ViewBuilder
    private func tabItems(tabWidth: CGFloat) -> some View {
        ForEach(Array(group.sessionIDs.enumerated()), id: \.element) { index, sessionID in
            if let session = viewModel.session(for: sessionID) {
                TerminalGroupTabItem(
                    viewModel: viewModel,
                    group: group,
                    session: session,
                    tabWidth: tabWidth,
                    isLast: index == group.sessionIDs.count - 1
                )
            }
        }
    }
}

// MARK: - Tab Layout

/// VS Code-style tab sizing: grow/shrink to fit, scroll only at minimum width.
struct TerminalTabLayoutMetrics {
    let tabWidth: CGFloat
    let needsScroll: Bool

    init(
        availableWidth: CGFloat,
        tabCount: Int,
        minWidth: CGFloat = ShellLayout.tabMinWidth,
        maxWidth: CGFloat = ShellLayout.tabMaxWidth
    ) {
        guard tabCount > 0, availableWidth > 0 else {
            tabWidth = maxWidth
            needsScroll = false
            return
        }

        let count = CGFloat(tabCount)
        let equalShare = availableWidth / count
        let fitted = min(maxWidth, max(minWidth, equalShare))
        let totalWidth = fitted * count

        if totalWidth <= availableWidth {
            tabWidth = fitted
            needsScroll = false
        } else {
            tabWidth = minWidth
            needsScroll = true
        }
    }
}

// MARK: - Tab Item

struct TerminalGroupTabItem: View {
    @ObservedObject var viewModel: SessionsViewModel
    var group: TerminalGroup
    var session: TerminalSession
    var tabWidth: CGFloat
    var isLast: Bool

    @State private var isHovered = false

    private var isSelected: Bool { session.id == group.selectedSessionID }

    private var dragPayload: TerminalTabDragPayload {
        TerminalTabDragPayload(
            sessionID: session.id,
            sourceGroupID: group.id,
            sourceWindowID: viewModel.windowID
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor(for: session.state))
                    .frame(width: 6, height: 6)

                Text(session.title)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .overlay {
                #if os(macOS)
                TerminalTabDragSource(
                    payload: dragPayload,
                    onSelect: {
                        viewModel.select(session.id, in: group.id)
                    },
                    onDragOutsideWindow: {
                        viewModel.detachTab(sessionID: session.id, from: group.id)
                    }
                )
                #else
                Color.clear
                    .onTapGesture {
                        viewModel.select(session.id, in: group.id)
                    }
                #endif
            }
            .dropDestination(for: TerminalTabDragPayload.self) { items, _ in
                guard let payload = items.first else { return false }
                guard TabDragDrop.shouldAccept(payload, in: group.id, before: session.id) else { return false }
                viewModel.handleTabDrop(payload, to: group.id, before: session.id)
                return true
            }

            Button {
                viewModel.close(session.id, in: group.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: 18, height: 18)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(AppTheme.elevatedPanel.opacity(closeButtonVisible ? 0.55 : 0))
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plainClickable)
            .foregroundStyle(AppTheme.textSecondary.opacity(closeButtonVisible ? 1 : 0))
            .allowsHitTesting(closeButtonVisible)
            .help("Close Tab")
        }
        .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(width: tabWidth, height: ShellLayout.panelHeaderHeight)
        .background(tabFill)
        .overlay(alignment: .trailing) {
            if !isLast {
                tabSeparator
            }
        }
        .overlay {
            if isSelected {
                activeTabSideBorders
            }
        }
        .overlay(alignment: .bottom) {
            if isSelected {
                Rectangle()
                    .fill(AppTheme.editor)
                    .frame(height: 1)
                    .offset(y: 1)
            }
        }
        .focusEffectDisabled()
        .zIndex(isSelected ? 1 : 0)
        .onHover { isHovered = $0 }
        .pointerCursor()
        .contextMenu { tabContextMenu }
    }

    private var closeButtonVisible: Bool {
        isHovered || isSelected
    }

    private var tabFill: Color {
        if isSelected { return AppTheme.editor }
        if isHovered { return AppTheme.elevatedPanel.opacity(0.22) }
        return Color.clear
    }

    private var tabSeparator: some View {
        Rectangle()
            .fill(AppTheme.panelStroke.opacity(isSelected ? 0.35 : 0.50))
            .frame(width: 1)
            .padding(.vertical, isSelected ? 0 : 7)
    }

    private var activeTabSideBorders: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(AppTheme.panelStroke.opacity(0.40))
                .frame(width: 1)
            Spacer(minLength: 0)
            Rectangle()
                .fill(AppTheme.panelStroke.opacity(0.40))
                .frame(width: 1)
        }
    }

    @ViewBuilder private var tabContextMenu: some View {
        Button("Move to New Window") {
            viewModel.detachTab(sessionID: session.id, from: group.id)
        }

        Divider()

        Button("Move to Split Right") {
            viewModel.moveTabToNewSplit(sessionID: session.id, from: group.id, placement: .right)
        }
        Button("Move to Split Down") {
            viewModel.moveTabToNewSplit(sessionID: session.id, from: group.id, placement: .down)
        }
        Button("Move to Split Left") {
            viewModel.moveTabToNewSplit(sessionID: session.id, from: group.id, placement: .left)
        }
        Button("Move to Split Up") {
            viewModel.moveTabToNewSplit(sessionID: session.id, from: group.id, placement: .up)
        }

        Divider()

        ForEach(viewModel.groups.filter { $0.id != group.id }) { targetGroup in
            Button("Move to \(viewModel.groupDisplayLabel(for: targetGroup.id))") {
                viewModel.moveTab(sessionID: session.id, to: targetGroup.id)
            }
        }

        Divider()

        Button("Close Tab") {
            viewModel.close(session.id, in: group.id)
        }
    }

    private func statusColor(for state: ConnectionState) -> Color {
        switch state {
        case .connected:     return AppTheme.success
        case .connecting, .reconnecting: return AppTheme.warning
        case .failed:        return AppTheme.danger
        case .disconnected:  return AppTheme.textTertiary
        }
    }
}

// MARK: - More Actions Menu

/// Overflow menu for less-frequent actions: split left/up, move to group, close tabs.
struct GroupMoreMenu: View {
    @ObservedObject var viewModel: SessionsViewModel
    var group: TerminalGroup

    private var activeSessionID: UUID? { group.selectedSessionID }

    var body: some View {
        Menu {
            lesserSplitCommands
            Divider()
            moveToGroupCommands
            Divider()
            closeCommands
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(.plainClickable)
        .foregroundStyle(AppTheme.textSecondary)
        .help("More Actions")
    }

    @ViewBuilder private var lesserSplitCommands: some View {
        Button("Split Left") {
            viewModel.splitGroup(group.id, placement: .left)
        }
        Button("Split Up") {
            viewModel.splitGroup(group.id, placement: .up)
        }
        if let id = activeSessionID {
            Divider()
            Button("Move Active Tab to Split Left") {
                viewModel.moveTabToNewSplit(sessionID: id, from: group.id, placement: .left)
            }
            Button("Move Active Tab to Split Up") {
                viewModel.moveTabToNewSplit(sessionID: id, from: group.id, placement: .up)
            }
            Button("Move Active Tab to Split Right") {
                viewModel.moveTabToNewSplit(sessionID: id, from: group.id, placement: .right)
            }
            Button("Move Active Tab to Split Down") {
                viewModel.moveTabToNewSplit(sessionID: id, from: group.id, placement: .down)
            }
        }
    }

    @ViewBuilder private var moveToGroupCommands: some View {
        let otherGroups = viewModel.groups.filter { $0.id != group.id }
        if let id = activeSessionID, !otherGroups.isEmpty {
            ForEach(otherGroups) { target in
                Button("Move Active Tab to \(viewModel.groupDisplayLabel(for: target.id))") {
                    viewModel.moveTab(sessionID: id, to: target.id)
                }
            }
        } else {
            Text("No other groups")
        }
    }

    @ViewBuilder private var closeCommands: some View {
        Button("Close Tabs in Group") {
            viewModel.closeGroupTabs(group.id)
        }
    }
}

// MARK: - Shared Button

/// Compact icon button used in the group action toolbar.
struct GroupActionButton: View {
    var systemImage: String
    var help: String
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.elevatedPanel.opacity(isHovered ? 0.7 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plainClickable)
        .foregroundStyle(isHovered ? AppTheme.textPrimary : AppTheme.textSecondary)
        .help(help)
        .onHover { isHovered = $0 }
    }
}

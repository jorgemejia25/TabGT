import Testing
@testable import TabGT

struct WorkspaceLayoutTests {
    @MainActor
    @Test func initialLayoutCreatesOneFocusedGroup() {
        let viewModel = SessionsViewModel(sessions: PreviewData.sessions)

        guard case .group(let group) = viewModel.layout.root else {
            Issue.record("Expected initial layout to be a terminal group")
            return
        }

        #expect(group.sessionIDs == PreviewData.sessions.map(\.id))
        #expect(group.selectedSessionID == PreviewData.sessions.first?.id)
        #expect(viewModel.layout.focusedGroupID == group.id)
    }

    @MainActor
    @Test func splitGroupCreatesRecursiveSplitAndFocusesNewGroup() {
        let viewModel = SessionsViewModel(sessions: PreviewData.sessions)
        let originalGroupID = viewModel.layout.focusedGroupID

        viewModel.splitGroup(originalGroupID, axis: .horizontal)

        guard case .split(let split) = viewModel.layout.root,
              case .group(let leadingGroup) = split.leading,
              case .group(let trailingGroup) = split.trailing
        else {
            Issue.record("Expected root split with two terminal groups")
            return
        }

        #expect(split.axis == .horizontal)
        #expect(leadingGroup.id == originalGroupID)
        #expect(trailingGroup.sessionIDs.count == 1)
        #expect(viewModel.session(for: trailingGroup.sessionIDs[0])?.kind == PreviewData.sessions.first?.kind)
        #expect(viewModel.layout.focusedGroupID == trailingGroup.id)
    }

    @MainActor
    @Test func movingTabBetweenGroupsUpdatesSourceDestinationAndSelection() {
        let viewModel = SessionsViewModel(sessions: PreviewData.sessions)
        let originalGroupID = viewModel.layout.focusedGroupID
        let sessionID = PreviewData.sessions[0].id

        viewModel.splitGroup(originalGroupID, axis: .vertical)

        guard case .split(let initialSplit) = viewModel.layout.root,
              case .group(let trailingGroup) = initialSplit.trailing
        else {
            Issue.record("Expected root split")
            return
        }

        viewModel.moveTab(sessionID: sessionID, to: trailingGroup.id)

        let groups = groups(in: viewModel.layout.root)
        let source = groups.first { $0.id == originalGroupID }
        let destination = groups.first { $0.id == trailingGroup.id }

        #expect(source?.sessionIDs.contains(sessionID) == false)
        #expect(destination?.sessionIDs.contains(sessionID) == true)
        #expect(destination?.selectedSessionID == sessionID)
        #expect(viewModel.layout.focusedGroupID == trailingGroup.id)
    }

    @MainActor
    @Test func splitLeftPlacesNewGroupBeforeCurrentGroup() {
        let viewModel = SessionsViewModel(sessions: PreviewData.sessions)
        let originalGroupID = viewModel.layout.focusedGroupID

        viewModel.splitGroup(originalGroupID, placement: .left)

        guard case .split(let split) = viewModel.layout.root,
              case .group(let leadingGroup) = split.leading,
              case .group(let trailingGroup) = split.trailing
        else {
            Issue.record("Expected root split with two terminal groups")
            return
        }

        #expect(split.axis == .horizontal)
        #expect(leadingGroup.id == viewModel.layout.focusedGroupID)
        #expect(trailingGroup.id == originalGroupID)
    }

    @MainActor
    @Test func moveTabToNewSplitKeepsRemainingTabsInSourceGroup() {
        let viewModel = SessionsViewModel(sessions: PreviewData.sessions)
        let sourceGroupID = viewModel.layout.focusedGroupID
        let movedSessionID = PreviewData.sessions[0].id
        let retainedSessionID = PreviewData.sessions[1].id

        viewModel.moveTabToNewSplit(
            sessionID: movedSessionID,
            from: sourceGroupID,
            around: sourceGroupID,
            placement: .right
        )

        guard case .split(let split) = viewModel.layout.root,
              case .group(let sourceGroup) = split.leading,
              case .group(let newGroup) = split.trailing
        else {
            Issue.record("Expected moved tab to create a new split")
            return
        }

        #expect(sourceGroup.sessionIDs == [retainedSessionID])
        #expect(newGroup.sessionIDs == [movedSessionID])
        #expect(newGroup.selectedSessionID == movedSessionID)
        #expect(viewModel.layout.focusedGroupID == newGroup.id)
    }

    @MainActor
    @Test func openSSHSessionAllowsDuplicateProfileTabsInSameGroup() {
        let viewModel = SessionsViewModel()
        let host = PreviewData.hosts[0]
        let groupID = viewModel.layout.focusedGroupID

        viewModel.openSSHSession(for: host)
        viewModel.openSSHSession(for: host)

        guard let group = viewModel.layout.root.group(id: groupID) else {
            Issue.record("Expected focused group to exist")
            return
        }

        let hostSessions = viewModel.sessions.filter {
            $0.kind.hostID == host.id
        }

        #expect(hostSessions.count == 2)
        #expect(group.sessionIDs.count == 2)
        #expect(group.sessionIDs.allSatisfy { sessionID in
            hostSessions.contains { $0.id == sessionID }
        })
        #expect(group.selectedSessionID == hostSessions.last?.id)
    }

    @MainActor
    @Test func splitRatioIsClampedForResizableDividers() {
        let viewModel = SessionsViewModel(sessions: PreviewData.sessions)
        let originalGroupID = viewModel.layout.focusedGroupID

        viewModel.splitGroup(originalGroupID, placement: .right)

        guard case .split(let initialSplit) = viewModel.layout.root else {
            Issue.record("Expected root split")
            return
        }

        viewModel.updateSplitRatio(initialSplit.id, ratio: 0.95)

        guard case .split(let updatedSplit) = viewModel.layout.root else {
            Issue.record("Expected root split after update")
            return
        }

        #expect(updatedSplit.ratio == 0.82)
    }

    @MainActor
    @Test func selectTabAtIndexFocusesRequestedSession() {
        let viewModel = SessionsViewModel(sessions: PreviewData.sessions)
        let groupID = viewModel.layout.focusedGroupID

        viewModel.selectTab(at: 1)

        guard let group = viewModel.layout.root.group(id: groupID) else {
            Issue.record("Expected focused group")
            return
        }

        #expect(group.selectedSessionID == PreviewData.sessions[1].id)
    }

    @MainActor
    @Test func groupDisplayLabelUsesOneBasedTabNumbers() {
        let viewModel = SessionsViewModel(sessions: PreviewData.sessions)
        let firstGroupID = viewModel.layout.focusedGroupID

        viewModel.splitGroup(firstGroupID, placement: .right)

        let labels = viewModel.groups.map { viewModel.groupDisplayLabel(for: $0.id) }
        #expect(labels == ["Tab 1", "Tab 2"])
    }

    private func groups(in node: WorkspaceNode) -> [TerminalGroup] {
        switch node {
        case .group(let group):
            return [group]
        case .split(let split):
            return groups(in: split.leading) + groups(in: split.trailing)
        }
    }
}

import SwiftUI

struct TerminalGroupView: View {
    var group: TerminalGroup
    @ObservedObject var viewModel: SessionsViewModel
    @ObservedObject var connections: ConnectionsViewModel
    @ObservedObject var terminalProfiles: TerminalProfilesViewModel
    @ObservedObject var snippets: SnippetsViewModel
    @ObservedObject var inputBridge: SessionInputBridge

    @State private var isDropTargeted = false
    @State private var dropHoverPlacement: TerminalSplitPlacement?

    var body: some View {
        VStack(spacing: 0) {
            SessionTabsView(
                viewModel: viewModel,
                terminalProfiles: terminalProfiles,
                group: group
            )

            terminalContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.editor)
                .overlay {
                    splitDropLayer
                }
        }
        .contentShape(Rectangle())
        .onTapGesture { viewModel.focusGroup(group.id) }
    }

    @ViewBuilder
    private var splitDropLayer: some View {
        ZStack {
            #if os(macOS)
            TerminalSplitDropTarget(
                onTargetedChanged: { isDropTargeted = $0 },
                onPlacementChanged: { dropHoverPlacement = $0 },
                onDrop: { payload, placement in
                    handleSplitDrop(payload: payload, placement: placement)
                }
            )
            #endif

            if isDropTargeted {
                SplitDropOverlay(placement: dropHoverPlacement)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private var terminalContent: some View {
        Group {
            if group.sessionIDs.isEmpty {
                emptyGroup
            } else {
                // One terminal surface per session. Reusing a single NSViewRepresentable
                // across tabs would keep the first PTY alive for every tab switch.
                ZStack {
                    ForEach(group.sessionIDs, id: \.self) { sessionID in
                        if let session = viewModel.session(for: sessionID) {
                            TerminalContainerView(
                                session: session,
                                sessions: viewModel,
                                connections: connections,
                                terminalProfiles: terminalProfiles,
                                snippets: snippets,
                                inputBridge: inputBridge
                            )
                            .id(session.id)
                            .opacity(group.selectedSessionID == sessionID ? 1 : 0)
                            .allowsHitTesting(group.selectedSessionID == sessionID)
                            .accessibilityHidden(group.selectedSessionID != sessionID)
                        }
                    }
                }
            }
        }
    }

    private var emptyGroup: some View {
        VStack(spacing: 12) {
            Text("No terminal")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AppTheme.textTertiary)

            Button {
                if let profile = terminalProfiles.defaultProfile {
                    viewModel.openLocalSession(profile: profile, in: group.id)
                } else {
                    viewModel.openLocalSession(in: group.id)
                }
            } label: {
                Text("New Terminal")
                    .font(.system(size: 12, weight: .regular))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.plainClickable)
            .background(AppTheme.elevatedPanel, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleSplitDrop(
        payload: TerminalTabDragPayload,
        placement: TerminalSplitPlacement?
    ) -> Bool {
        if let placement {
            viewModel.moveTabToNewSplit(
                sessionID: payload.sessionID,
                from: payload.sourceGroupID,
                around: group.id,
                placement: placement
            )
            return true
        }

        guard payload.sourceGroupID != group.id else { return false }

        viewModel.moveTab(sessionID: payload.sessionID, to: group.id)
        return true
    }
}

// MARK: - Split drop preview

struct SplitDropOverlay: View {
    var placement: TerminalSplitPlacement?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if placement == nil {
                    Color.black.opacity(0.04)
                }

                if let placement {
                    splitPreview(for: placement, in: proxy.size)
                }
            }
        }
    }

    @ViewBuilder
    private func splitPreview(for placement: TerminalSplitPlacement, in size: CGSize) -> some View {
        let halfWidth = size.width * 0.5
        let halfHeight = size.height * 0.5
        let previewFill = AppTheme.selectionBlue.opacity(0.22)
        let previewStroke = AppTheme.selectionBlue.opacity(0.85)

        switch placement {
        case .left:
            Rectangle()
                .fill(previewFill)
                .overlay(alignment: .trailing) {
                    Rectangle().fill(previewStroke).frame(width: 2)
                }
                .frame(width: halfWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        case .right:
            Rectangle()
                .fill(previewFill)
                .overlay(alignment: .leading) {
                    Rectangle().fill(previewStroke).frame(width: 2)
                }
                .frame(width: halfWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        case .up:
            Rectangle()
                .fill(previewFill)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(previewStroke).frame(height: 2)
                }
                .frame(height: halfHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        case .down:
            Rectangle()
                .fill(previewFill)
                .overlay(alignment: .top) {
                    Rectangle().fill(previewStroke).frame(height: 2)
                }
                .frame(height: halfHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}

enum SplitDropPlacement {
    static func placementAt(_ location: CGPoint, in size: CGSize) -> TerminalSplitPlacement? {
        guard size.width > 0, size.height > 0 else { return nil }

        let normalizedX = location.x / size.width
        let normalizedY = location.y / size.height
        let edgeBias = 0.22

        let distances: [(TerminalSplitPlacement, Double)] = [
            (.left, normalizedX),
            (.right, 1 - normalizedX),
            (.up, normalizedY),
            (.down, 1 - normalizedY)
        ]

        guard let closest = distances.min(by: { $0.1 < $1.1 }),
              closest.1 <= edgeBias
        else {
            return nil
        }

        return closest.0
    }
}

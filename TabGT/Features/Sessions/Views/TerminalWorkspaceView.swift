import AppKit
import SwiftUI

struct TerminalWorkspaceView: View {
    @ObservedObject var viewModel: SessionsViewModel
    @ObservedObject var connections: ConnectionsViewModel
    @ObservedObject var terminalProfiles: TerminalProfilesViewModel
    @ObservedObject var snippets: SnippetsViewModel
    @ObservedObject var inputBridge: SessionInputBridge

    var body: some View {
        WorkspaceNodeView(
            node: viewModel.layout.root,
            viewModel: viewModel,
            connections: connections,
            terminalProfiles: terminalProfiles,
            snippets: snippets,
            inputBridge: inputBridge
        )
    }
}

private struct WorkspaceNodeView: View {
    var node: WorkspaceNode
    @ObservedObject var viewModel: SessionsViewModel
    @ObservedObject var connections: ConnectionsViewModel
    @ObservedObject var terminalProfiles: TerminalProfilesViewModel
    @ObservedObject var snippets: SnippetsViewModel
    @ObservedObject var inputBridge: SessionInputBridge

    var body: some View {
        switch node {
        case .group(let group):
            TerminalGroupView(
                group: group,
                viewModel: viewModel,
                connections: connections,
                terminalProfiles: terminalProfiles,
                snippets: snippets,
                inputBridge: inputBridge
            )
        case .split(let split):
            WorkspaceSplitView(
                split: split,
                viewModel: viewModel,
                connections: connections,
                terminalProfiles: terminalProfiles,
                snippets: snippets,
                inputBridge: inputBridge
            )
        }
    }
}

// MARK: - Split View

/// Hosts two workspace nodes separated by an interactive sash.
///
/// Ghost-resize strategy: the leading and trailing panels keep their committed
/// sizes while the user drags. Only the sash line moves. When the drag ends the
/// new ratio is committed once, causing exactly one layout pass in the panels
/// (no per-frame resize of the underlying NSViews).
private struct WorkspaceSplitView: View {
    var split: TerminalSplit
    @ObservedObject var viewModel: SessionsViewModel
    @ObservedObject var connections: ConnectionsViewModel
    @ObservedObject var terminalProfiles: TerminalProfilesViewModel
    @ObservedObject var snippets: SnippetsViewModel
    @ObservedObject var inputBridge: SessionInputBridge

    @State private var isDragging = false
    @State private var dragStartRatio: Double?
    @State private var ghostRatio: Double?

    /// Sash position during drag; falls back to committed ratio when idle.
    private var ghostPosition: Double { ghostRatio ?? split.ratio }

    var body: some View {
        GeometryReader { geo in
            let isHorizontal = split.axis == .horizontal
            let totalLength = max(1, isHorizontal ? geo.size.width : geo.size.height)

            // Committed panel sizes – constant during the entire drag.
            let firstLength  = totalLength * CGFloat(split.ratio)
            let secondLength = max(1, totalLength - firstLength)

            // Ghost sash offset (changes while dragging).
            let ghostOffset  = totalLength * CGFloat(ghostPosition)

            ZStack(alignment: .topLeading) {
                // Panels flush edge-to-edge – no layout gap (avoids a dark stripe between groups).
                if isHorizontal {
                    HStack(spacing: 0) {
                        WorkspaceNodeView(
                            node: split.leading,
                            viewModel: viewModel,
                            connections: connections,
                            terminalProfiles: terminalProfiles,
                            snippets: snippets,
                            inputBridge: inputBridge
                        )
                            .frame(width: firstLength)
                            .clipped()
                        WorkspaceNodeView(
                            node: split.trailing,
                            viewModel: viewModel,
                            connections: connections,
                            terminalProfiles: terminalProfiles,
                            snippets: snippets,
                            inputBridge: inputBridge
                        )
                            .frame(width: secondLength)
                            .clipped()
                    }
                } else {
                    VStack(spacing: 0) {
                        WorkspaceNodeView(
                            node: split.leading,
                            viewModel: viewModel,
                            connections: connections,
                            terminalProfiles: terminalProfiles,
                            snippets: snippets,
                            inputBridge: inputBridge
                        )
                            .frame(height: firstLength)
                            .clipped()
                        WorkspaceNodeView(
                            node: split.trailing,
                            viewModel: viewModel,
                            connections: connections,
                            terminalProfiles: terminalProfiles,
                            snippets: snippets,
                            inputBridge: inputBridge
                        )
                            .frame(height: secondLength)
                            .clipped()
                    }
                }

                // Interactive sash – follows ghost position only.
                SplitSash(axis: split.axis, isDragging: $isDragging) { delta in
                    updateGhost(delta: delta, totalLength: totalLength)
                } onDragStarted: {
                    dragStartRatio = split.ratio
                    isDragging = true
                } onDragEnded: {
                    if let g = ghostRatio {
                        viewModel.updateSplitRatio(split.id, ratio: g)
                    }
                    isDragging = false
                    dragStartRatio = nil
                    ghostRatio = nil
                }
                .frame(
                    width:  isHorizontal ? SashMetrics.hitArea : geo.size.width,
                    height: isHorizontal ? geo.size.height     : SashMetrics.hitArea
                )
                .offset(
                    x: isHorizontal ? ghostOffset - (SashMetrics.hitArea / 2) : 0,
                    y: isHorizontal ? 0 : ghostOffset - (SashMetrics.hitArea / 2)
                )
            }
        }
        .id(split.id)
    }

    private func updateGhost(delta: CGFloat, totalLength: CGFloat) {
        let base    = CGFloat(dragStartRatio ?? split.ratio)
        let raw     = (base * totalLength + delta) / totalLength
        ghostRatio  = min(max(Double(raw), SashMetrics.minRatio), SashMetrics.maxRatio)
    }
}

// MARK: - Sash

private enum SashMetrics {
    static let hitArea: CGFloat = 5
    static let minRatio = 0.18
    static let maxRatio = 0.82
}

/// A thin, interactive divider that appears between two split panes.
///
/// Visual width/height stays at 1 pt (like VS Code); the surrounding transparent
/// hit area is `SashMetrics.hitArea` pts so it is easy to grab.
private struct SplitSash: View {
    var axis: TerminalSplitAxis
    @Binding var isDragging: Bool
    var onDragChanged:  (CGFloat) -> Void
    var onDragStarted:  () -> Void
    var onDragEnded:    () -> Void

    @State private var hasStartedDrag = false

    private var resizeCursor: NSCursor {
        axis == .horizontal ? .resizeLeftRight : .resizeUpDown
    }

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())

            Rectangle()
                .fill(isDragging ? AppTheme.splitSashActive : AppTheme.shellBorder)
                .frame(
                    width:  axis == .horizontal ? 1 : nil,
                    height: axis == .vertical   ? 1 : nil
                )
        }
        .hoverCursor(resizeCursor, isDragging: isDragging)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    if !hasStartedDrag {
                        hasStartedDrag = true
                        onDragStarted()
                    }
                    let delta = axis == .horizontal
                        ? value.translation.width
                        : value.translation.height
                    onDragChanged(delta)
                }
                .onEnded { _ in
                    hasStartedDrag = false
                    onDragEnded()
                }
        )
        .help("Drag to resize")
    }
}

import AppKit
import SwiftUI

/// Interactive resize strip centered on a shell panel edge.
///
/// The 1 pt divider stays centered inside a transparent hit area so panels stay
/// flush in the layout (no extra gutter column).
struct ShellPanelResizeGrip: View {
    enum PanelEdge {
        case navigatorTrailing
        case inspectorLeading
    }

    var edge: PanelEdge
    @Binding var panelWidth: CGFloat
    var minWidth: CGFloat
    var maxWidth: CGFloat

    @State private var dragStartWidth: CGFloat?
    @State private var isHovered = false
    @State private var isDragging = false

    private let dragThreshold: CGFloat = 3
    private static let hitArea: CGFloat = 5

    /// Half the hit area — centers the grip on the panel edge when overlaid.
    static var edgeOffset: CGFloat { hitArea / 2 }

    var body: some View {
        ZStack {
            Color.clear

            if isActive {
                Rectangle()
                    .fill(AppTheme.splitSashActive)
                    .frame(width: 1)
            }
        }
        .frame(width: Self.hitArea)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .hoverCursor(.resizeLeftRight, isDragging: isDragging)
        .onHover { isHovered = $0 }
        .gesture(
            DragGesture(minimumDistance: dragThreshold, coordinateSpace: .global)
                .onChanged { value in
                    if dragStartWidth == nil {
                        dragStartWidth = panelWidth
                        isDragging = true
                    }

                    guard let start = dragStartWidth else { return }

                    let delta = value.translation.width
                    let signedDelta = edge == .navigatorTrailing ? delta : -delta
                    panelWidth = min(max(start + signedDelta, minWidth), maxWidth)
                }
                .onEnded { _ in
                    dragStartWidth = nil
                    isDragging = false
                }
        )
        .help("Drag to resize")
    }

    private var isActive: Bool { isHovered || isDragging }
}

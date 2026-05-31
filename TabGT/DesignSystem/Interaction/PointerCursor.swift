import SwiftUI

#if os(macOS)
import AppKit
#endif

extension View {
    /// Shows a custom cursor while the pointer is over this view.
    func pointerCursor(_ cursor: PointerCursor = .pointingHand) -> some View {
        #if os(macOS)
        hoverCursor(cursor.nsCursor)
        #else
        self
        #endif
    }

    #if os(macOS)
    /// Shows an AppKit cursor on hover; optionally keeps it visible while dragging.
    func hoverCursor(_ cursor: NSCursor, isDragging: Bool = false) -> some View {
        modifier(HoverCursorModifier(cursor: cursor, isDragging: isDragging))
    }
    #endif
}

enum PointerCursor {
    case pointingHand
    case arrow
    case iBeam

    #if os(macOS)
    var nsCursor: NSCursor {
        switch self {
        case .pointingHand: return .pointingHand
        case .arrow:        return .arrow
        case .iBeam:        return .iBeam
        }
    }
    #endif
}

#if os(macOS)
private struct HoverCursorModifier: ViewModifier {
    let cursor: NSCursor
    let isDragging: Bool

    @State private var isHovered = false
    @State private var cursorApplied = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovered = hovering
                updateCursor(forceSet: false)
            }
            .onChange(of: isDragging) { _, dragging in
                updateCursor(forceSet: dragging)
            }
    }

    private func updateCursor(forceSet: Bool) {
        let active = isHovered || isDragging

        if forceSet {
            cursor.set()
            cursorApplied = true
            return
        }

        if active, !cursorApplied {
            cursor.push()
            cursorApplied = true
        } else if !active, cursorApplied {
            NSCursor.pop()
            cursorApplied = false
        }
    }
}
#endif

/// Plain macOS button style with pointer cursor and subtle press feedback.
struct PlainClickableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .pointerCursor()
    }
}

extension ButtonStyle where Self == PlainClickableButtonStyle {
    static var plainClickable: PlainClickableButtonStyle { PlainClickableButtonStyle() }
}
